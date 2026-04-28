#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: localai-contributor
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://localai.io/

APP="LocalAI"
var_tags="ai;llm"
var_cpu="4"
var_ram="8192"
var_disk="20"
var_os="debian"
var_version="12"
var_unprivileged="1"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -d /opt/localai ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    if check_for_gh_release "localai" "mudler/LocalAI"; then
        msg_info "Stopping Service"
        systemctl stop localai
        msg_ok "Stopped Service"

        msg_info "Backing up Data"
        cp -r /opt/localai/models /opt/localai_models_backup
        msg_ok "Backed up Data"

        CLEAN_INSTALL=1 fetch_and_deploy_gh_release "localai" "mudler/LocalAI" "tarball" "latest" "/opt/localai"
        
        msg_info "Building Application"
        cd /opt/localai
        $STD make build
        msg_ok "Built Application"

        msg_info "Restoring Data"
        cp -r /opt/localai_models_backup/. /opt/localai/models/
        rm -rf /opt/localai_models_backup
        msg_ok "Restored Data"

        msg_info "Starting Service"
        systemctl start localai
        msg_ok "Started Service"
        msg_ok "Updated successfully!"
    fi
    exit
}

start
build_container
description
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
