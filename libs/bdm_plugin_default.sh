#!/bin/bash

# Upstream-Name: berb-docker-mgr
# Source: https://github.com/berbascum/berb-docker-mgr
#
## Plugin to do basic docker containers management
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



fn_docker_menu_actions_basic() {
    ## Function to get a action
#    fn_bbgl_ifs_2_newline activa
    docker_mode="default"
    ## Docker constants
    CONTAINER_BASE_NAME=""
    IMAGE_BASE_NAME="ghcr.io/berbascum/${CONTAINER_BASE_NAME}"
    IMAGE_BASE_TAG="${host_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='berb/build-essential'
    IMAGE_COMMIT_TAG="${droidian_suite}-${host_arch}"
    arr_actions_base=( \
	"create container" \
	"remove container" \
	"start container" \
	"stop container" \
	"shell to container" \
	"command to container" \
	"commit container" \
    )


    arr_data=( "${arr_actions_base[@]}" )
    fn_bssf_menu_fzf "action" "single"
    ACTION=$(echo "${item_selected}" | sed 's/ /_/g')
    debug "ACTION = ${ACTION}"

    FN_ACTION="fn_${ACTION}"
    info "Action selected = \"${ACTION}\""
    info "Plugin fn selected = \"${FN_ACTION}\""

    [[ -z "${ACTION}" ]] error "Action selection failed!"

    ## Crida la fn_action_ corresponent
    debug "Calling function \"${FN_ACTION}\""
    eval ${FN_ACTION}


 #   fn_bbgl_ifs_2_newline desactiva
}


<< "DISABLED_DEPRECATED"
## Execute action on container name
if [ "$ACTION" == "create" ]; then
    fn_create_container
elif [ "$ACTION" == "remove" ]; then
    fn_remove_container
elif [ "$ACTION" == "start" ]; then
    fn_start_container
elif [ "$ACTION" == "stop" ]; then
    fn_stop_container
elif [ "$ACTION" == "shell-to" ]; then
    fn_shell_to_container
elif [ "$ACTION" == "command-to" ]; then
   fn_cmd_on_container
    fn_install_apt_extra
elif [ "$ACTION" == "commit-container" ]; then
    fn_commit_container




    case ${answer} in
	1)
	    ACTION="create"
	    ;;
	2)
	    ACTION="remove"
	    ;;
	3)
	    ACTION="start"
	    ;;
	4)
	    ACTION="stop"
	    ;;
	5)
	    ACTION="commit-container"
	    ;;
	#6)
	 #   ACTION="install-apt-extra"
	 #   ;;
	7)
	    ACTION="shell-to"
	    ;;
	8)
	    ACTION="command-to"
	    ;;
DISABLED_DEPRECATED
