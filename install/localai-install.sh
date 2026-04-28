#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: localai-contributor
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://localai.io/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

setup_hwaccel

msg_info "Installing Base Dependencies"
$STD apt install -y \
  build-essential \
  cmake \
  protobuf-compiler-grpc \
  make \
  gcc \
  g++ \
  software-properties-common \
  pciutils \
  gpg-agent \
  wget \
  curl \
  ca-certificates \
  libopenblas-dev \
  libclblast-dev
msg_ok "Installed Base Dependencies"

msg_info "Setting up Vulkan & Intel Repositories"
# Setup Intel repos
mkdir -p /usr/share/keyrings
curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg 2>/dev/null || true
cat <<EOF >/etc/apt/sources.list.d/intel-gpu.sources
Types: deb
URIs: https://repositories.intel.com/gpu/ubuntu
Suites: jammy
Components: client
Architectures: amd64 i386
Signed-By: /usr/share/keyrings/intel-graphics.gpg
EOF
$STD apt update
msg_ok "Set up Intel Repositories"

msg_info "Installing GPU SDKs (Intel, Vulkan)"
# Intel
if is_debian && [[ "$(get_os_version_major)" -ge 13 ]]; then
  $STD apt -y install libze1 libze-dev intel-level-zero-gpu 2>/dev/null || true
else
  $STD apt -y install intel-level-zero-gpu level-zero level-zero-dev 2>/dev/null || true
fi
$STD apt install -y --no-install-recommends intel-basekit-2024.1 2>/dev/null || true

# Vulkan
$STD apt install -y mesa-vulkan-drivers vulkan-tools libvulkan-dev
msg_ok "Installed GPU SDKs"

msg_info "Setting up NVIDIA CUDA Repository"
curl -fsSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
$STD dpkg -i cuda-keyring_1.1-1_all.deb
rm -f cuda-keyring_1.1-1_all.deb
$STD apt update
msg_ok "Set up NVIDIA CUDA Repository"

msg_info "Installing NVIDIA CUDA Toolkit"
$STD apt install -y --no-install-recommends cuda-nvcc-12-0 libcublas-dev-12-0 libcusparse-dev-12-0
msg_ok "Installed NVIDIA CUDA Toolkit"

msg_info "Setting up AMD ROCm & HipBLAS"
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | tee /etc/apt/keyrings/rocm.gpg > /dev/null
cat <<EOF >/etc/apt/sources.list.d/rocm.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/debian jammy main
EOF
$STD apt update
$STD apt install -y --no-install-recommends hipblas-dev hipblaslt-dev rocblas-dev || true
msg_ok "Set up AMD ROCm & HipBLAS"

GO_VERSION="1.22" setup_go

msg_info "Setting up Protobuf for Go"
$STD go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
$STD go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@1958fcbe2ca8bd93af633f11e97d44e567e945af
msg_ok "Set up Protobuf for Go"

fetch_and_deploy_gh_release "localai" "mudler/LocalAI" "tarball" "latest" "/opt/localai"

msg_info "Building Application"
cd /opt/localai
$STD make build
msg_ok "Built Application"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/localai.service
[Unit]
Description=LocalAI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/localai
ExecStart=/opt/localai/local-ai --models-path=/opt/localai/models/ --host=0.0.0.0 --port=8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now localai
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
