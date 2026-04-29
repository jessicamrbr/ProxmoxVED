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
  libclblast-dev \
  pkg-config \
  zstd \
  gnupg \
  git \
  libarchive13 \
  net-tools \
  file \
  openssh-server \
  openssh-client
msg_ok "Installed Base Dependencies"

msg_info "Setting up Intel Repositories"
# Preparar diretório de chaves
mkdir -p /usr/share/keyrings

# Chave e Fonte: Intel GPU
curl -fsSL --retry 3 --retry-delay 5 https://repositories.intel.com/gpu/intel-graphics.key | gpg --yes --dearmor -o /usr/share/keyrings/intel-graphics.gpg
cat <<EOF >/etc/apt/sources.list.d/intel-gpu.sources
Types: deb
URIs: https://repositories.intel.com/gpu/ubuntu
Suites: noble/lts/2350
Components: unified
Architectures: amd64
Signed-By: /usr/share/keyrings/intel-graphics.gpg
EOF

# Chave e Fonte: Intel OneAPI
curl -fsSL --retry 3 --retry-delay 5 https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --yes --dearmor -o /usr/share/keyrings/oneapi-archive-keyring.gpg
cat <<EOF >/etc/apt/sources.list.d/oneAPI.sources
Types: deb
URIs: https://apt.repos.intel.com/oneapi
Suites: all
Components: main
Signed-By: /usr/share/keyrings/oneapi-archive-keyring.gpg
EOF

# Adicionar PPA Kobuk (Essencial para LXC Intel GPU)
$STD add-apt-repository -y ppa:kobuk-team/intel-graphics
$STD apt-get update
msg_ok "Setting up Intel Repositories"

msg_info "Installing Intel GPU SDK"
$STD apt-get install -y --no-install-recommends \
  intel-oneapi-runtime-libs \
  intel-opencl-icd \
  clinfo \
  intel-level-zero-gpu \
  libze1 \
  libze-dev \
  intel-metrics-discovery \
  intel-gsc \
  intel-ocloc \
  intel-basekit

cat << 'EOF' > /etc/profile.d/oneapi.sh
export ONEAPI_ROOT=/opt/intel/oneapi
export SETVARS_COMPLETED=1
export VTUNE_PROFILER_DIR=$ONEAPI_ROOT/vtune/2025.10
export TBBROOT=$ONEAPI_ROOT/tbb/2022.3/env/..
export MKLROOT=$ONEAPI_ROOT/mkl/2025.3
export I_MPI_ROOT=$ONEAPI_ROOT/mpi/2021.17
export PATH=$ONEAPI_ROOT/vtune/2025.10/bin64:$ONEAPI_ROOT/mpi/2021.17/bin:$ONEAPI_ROOT/mkl/2025.3/bin:$ONEAPI_ROOT/compiler/2025.3/bin:$PATH
export LD_LIBRARY_PATH=$ONEAPI_ROOT/tcm/1.4/lib:$ONEAPI_ROOT/umf/1.0/lib:$ONEAPI_ROOT/tbb/2022.3/env/../lib/intel64/gcc4.8:$ONEAPI_ROOT/mpi/2021.17/lib:$ONEAPI_ROOT/mkl/2025.3/lib:$ONEAPI_ROOT/compiler/2025.3/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$ONEAPI_ROOT/vtune/2025.10/include/pkgconfig/lib64:$ONEAPI_ROOT/mkl/2025.3/lib/pkgconfig:$PKG_CONFIG_PATH
EOF
chmod +x /etc/profile.d/oneapi.sh

msg_ok "Installed Intel GPU SDK"

# msg_info "Setting up NVIDIA Repository (CUDA)"
# curl -fsSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
# $STD dpkg -i cuda-keyring_1.1-1_all.deb
# rm -f cuda-keyring_1.1-1_all.deb
# $STD apt update
# msg_ok "Setting up NVIDIA Repository (CUDA)"

# msg_info "Installing Vulkan GPU SDK"
# $STD apt install -y mesa-vulkan-drivers vulkan-tools libvulkan-dev
# msg_ok "Installed Vulkan GPU SDK"

# msg_info "Installing NVIDIA Toolkit (CUDA)"
# $STD apt install -y --no-install-recommends cuda-nvcc-12-8 libcublas-dev-12-8 libcusparse-dev-12-8
# msg_ok "Installed NVIDIA Toolkit (CUDA)"

# msg_info "Setting up AMD Repositories"
# wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | tee /etc/apt/keyrings/rocm.gpg > /dev/null
# cat <<EOF >/etc/apt/sources.list.d/rocm.list
# deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/debian jammy main
# EOF
# $STD apt update
# msg_ok "Setting up AMD Repositories"

# msg_info "Setting up AMD GPU SDK & Toolkits (ROCm & HipBLAS)"
# $STD apt install -y --no-install-recommends hipblas-dev hipblaslt-dev rocblas-dev || true
# msg_ok "Setting up AMD GPU SDK & Toolkits (ROCm & HipBLAS)"

GO_VERSION="1.22.12" setup_go

NODE_VERSION="22" setup_nodejs

msg_info "Setting up Protobuf for Go"
export PATH=$PATH:/root/go/bin
$STD go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
$STD go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@1958fcbe2ca8bd93af633f11e97d44e567e945af
msg_ok "Set up Protobuf for Go"

fetch_and_deploy_gh_release "localai" "mudler/LocalAI" "tarball" "latest" "/opt/localai"

msg_info "Building Application"
cd /opt/localai
$STD make build
msg_ok "Built Application"

# msg_info "Setting up GPU Backends and Workarounds"
# # Prevent deadlock caused by intel_gpu_top on LXC during LocalAI hw polling
# if [ -f "/usr/bin/intel_gpu_top" ]; then
#   $STD mv /usr/bin/intel_gpu_top /usr/bin/intel_gpu_top.bak
# fi
# # Fetch Intel SYCL backend to enable iGPU offloading
# export LC_ALL=C
# $STD /opt/localai/local-ai backends install oci://quay.io/go-skynet/local-ai-backends:latest-gpu-intel-sycl-f16-llama-cpp intel-sycl-f16-llama-cpp || true
# msg_ok "Configured GPU Backends"


# # Fetch Intel SYCL backend to enable iGPU offloading
# export LC_ALL=C
# $STD /opt/localai/local-ai backends install oci://quay.io/go-skynet/local-ai-backends:latest-gpu-intel-sycl-f16-llama-cpp intel-sycl-f16-llama-cpp || true
# msg_ok "Configured GPU Backends"

setup_hwaccel

read -r -p "Enable LocalAGI (Agents) features? <y/N> " prompt_agi
if [[ ${prompt_agi,,} =~ ^(y|yes)$ ]]; then
  LOCALAI_DISABLE_AGENTS="false"
  LOCALAI_AGENT_POOL_ENABLE_SKILLS="true"
  read -r -p "Enter PostgreSQL Database URL for LocalAGI (Press enter to skip): " prompt_db_url
  if [[ -n "$prompt_db_url" ]]; then
    LOCALAI_AGENT_POOL_VECTOR_ENGINE="postgres"
    LOCALAI_AGENT_POOL_DATABASE_URL="$prompt_db_url"
  fi
else
  LOCALAI_DISABLE_AGENTS="true"
  LOCALAI_AGENT_POOL_ENABLE_SKILLS="false"
fi

msg_info "Generating Environment Variables"
cat <<EOF >/opt/localai/.env
## LocalAI Environment Configuration
## Set number of threads.
## Note: prefer the number of physical cores. Overbooking the CPU degrades performance notably.
# LOCALAI_THREADS=14

## Specify a different bind address (defaults to ":8080")
LOCALAI_ADDRESS=0.0.0.0:8080

## Default models context size
# LOCALAI_CONTEXT_SIZ
# # Fetch Intel SYCL backend to enable iGPU offloading
# export LC_ALL=C
# $STD /opt/localai/local-ai backends install oci://quay.io/go-skynet/local-ai-backends:latest-gpu-intel-sycl-f16-llama-cpp intel-sycl-f16-llama-cpp || true
# msg_ok "Configured GPU Backends"
E=512

## Define galleries.
## models will to install will be visible in `/models/available`
# LOCALAI_GALLERIES=[{"name":"localai", "url":"github:mudler/LocalAI/gallery/index.yaml@master"}]

## CORS settings
# LOCALAI_CORS=true
# LOCALAI_CORS_ALLOW_ORIGINS=*

## Default path for models
LOCALAI_MODELS_PATH=/opt/localai/models/

## Enable debug mode
DEBUG=true
# LOCALAI_LOG_LEVEL=debug

## Disables COMPEL (Diffusers)
# COMPEL=0

## Disables SD_EMBED (Diffusers)
# SD_EMBED=0

## Enable/Disable single backend (useful if only one GPU is available)
# LOCALAI_SINGLE_ACTIVE_BACKEND=true

# Forces shutdown of the backends if busy (only if LOCALAI_SINGLE_ACTIVE_BACKEND is set)
# LOCALAI_FORCE_BACKEND_SHUTDOWN=true

## Path where to store generated images
# LOCALAI_IMAGE_PATH=/tmp/generated/images

## Specify a default upload limit in MB (whisper)
# LOCALAI_UPLOAD_LIMIT=15

## List of external GRPC backends (note on the container image this variable is already set to use extra backends available in extra/)
# LOCALAI_EXTERNAL_GRPC_BACKENDS=my-backend:127.0.0.1:9000,my-backend2:/usr/bin/backend.py

## Advanced settings
## Those are not really used by LocalAI, but from components in the stack
## Preload libraries
# LD_PRELOAD=

## Huggingface cache for models
# HUGGINGFACE_HUB_CACHE=/usr/local/huggingface

## Python backends GRPC max workers
## Default number of workers for GRPC Python backends.
## This actually controls wether a backend can process multiple requests or not.
# PYTHON_GRPC_MAX_WORKERS=1

## Define the number of parallel LLAMA.cpp workers (Defaults to 1)
# LLAMACPP_PARALLEL=1

## Define a list of GRPC Servers for llama-cpp workers to distribute the load
# https://github.com/ggerganov/llama.cpp/pull/6829
# https://github.com/ggerganov/llama.cpp/blob/master/tools/rpc/README.md
# LLAMACPP_GRPC_SERVERS=""qwen3.5-9b-glm5.1-distill-v1

Error: failed to load model with internal loader: could not load model: rpc e

## Enable to run parallel requests
# LOCALAI_PARALLEL_REQUESTS=true

# Enable to allow p2p mode
# LOCALAI_P2P=true

# Enable to use federated mode
# LOCALAI_FEDERATED=true

# Enable to start federation server
# FEDERATED_SERVER=true

# Define to use federation token
# TOKEN=""

## Watchdog settings
##DEBUG=${LOCALAI_DEBUG}
# Enables watchdog to kill backends that are inactive for too much time
# LOCALAI_WATCHDOG_IDLE=true
#
# Time in duration format (e.g. 1h30m) after which a backend is considered idle
# LOCALAI_WATCHDOG_IDLE_TIMEOUT=5m
#
# Enables watchdog to kill backends that are busy for too much time
# LOCALAI_WATCHDOG_BUSY=true
#
# Time in duration format (e.g. 1h30m) after which a backend is considered busy
# LOCALAI_WATCHDOG_BUSY_TIMEOUT=5m

# Agents (LocalAGI) - https://localai.io/features/agents/
LOCALAI_DISABLE_AGENTS=${LOCALAI_DISABLE_AGENTS}
LOCALAI_AGENT_POOL_DEFAULT_MODEL=hermes-3-llama3.1-8b
LOCALAI_AGENT_POOL_ENABLE_SKILLS=${LOCALAI_AGENT_POOL_ENABLE_SKILLS}
LOCALAI_AGENT_POOL_ENABLE_LOGS=true
LOCALAI_AGENT_HUB_URL=https://agenthub.localai.io

## Custom GPU bypass and Backend Configuration
LOCALAI_FORCE_META_BACKEND_CAPABILITY=true
LOCALAI_BACKENDS_PATH=/backends
LLAMA_VULKAN=1
EOF

if [[ -n "${LOCALAI_AGENT_POOL_VECTOR_ENGINE}" ]]; then
cat <<EOF >>/opt/localai/.env

# Database settings
LOCALAI_AGENT_POOL_VECTOR_ENGINE=${LOCALAI_AGENT_POOL_VECTOR_ENGINE}
LOCALAI_AGENT_POOL_DATABASE_URL=${LOCALAI_AGENT_POOL_DATABASE_URL}
EOF
fi

msg_ok "Generated Environment Variables"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/localai.service
[Unit]
Description=LocalAI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/localai
EnvironmentFile=-/opt/localai/.env
ExecStart=/opt/localai/local-ai run
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
