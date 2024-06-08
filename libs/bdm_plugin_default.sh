#!/bin/bash

## Plugin to do basic docker containers management
#
# Upstream-Name: berb-docker-mgr
# Source: https://github.com/berbascum/berb-docker-mgr
#
# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
# All rights reserved.
#
# BSD 3-Clause License
#
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the <organization> nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[ -z "$(echo "$@" | grep "\-\-run")" ] && abort "Needs to be called with yhe --run flag"

fn_docker_plugin_conf() {
    docker_mode="default"
    ## Docker constants
    CONTAINER_BASE_NAME="berb-build-env"
    IMAGE_BASE_NAME="ghcr.io/berbascum/berb-build-env"
    IMAGE_BASE_TAG="${host_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='berb/build-essential'
    IMAGE_COMMIT_TAG="${droidian_suite}-${host_arch}"
    fn_bdm_docker_global_config
    arr_actions_plugin=( "exit" )
    declare -g arr_data=( "${arr_actions_plugin[@]}" "${arr_actions_base[@]}" )
}

fn_docker_plugin_conf
while [ "${exit}" != "True" ]; do
    fn_bdm_docker_menu_fzf
done

