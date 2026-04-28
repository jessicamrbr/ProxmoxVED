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

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  cmake \
  protobuf-compiler-grpc \
  make \
  gcc \
  g++
msg_ok "Installed Dependencies"

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
