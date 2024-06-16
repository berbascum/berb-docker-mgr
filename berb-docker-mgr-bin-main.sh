#!/bin/bash

## Script to manage docker containers
#
# Upstream-Name: berb-docker-mgr
# Source: https://github.com/berbascum/berb-docker-mgr
#
# Copyright (C) 2022 Berbascum <berbascum@ticv.cat>
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


#################
## Header vars ##
#################

#[HEADER_SECTION]
fn_header_info() {
    BIN_TYPE="bin"
    BIN_SRC_TYPE="bash"
    BIN_SRC_EXT="sh"
    BIN_NAME="berb-docker-mgr"
    TOOL_VERSION="2.1.1.1"
    TOOL_RELEASE="sid"
    URGENCY='optional'
    TESTED_BASH_VER='5.2.15'
}
TOOL_NAME="berb-docker-mgr"
BBL_GIT_VERSION="1001"
BBL_GENERAL_VERSION="1001"
BBL_NET_VERSION="1001"
#[HEADER_END]

#######################
## General functions ##
#######################
fn_bdm_global_conf() {
    ## Libs path vars
    LIBS_FULLPATH="/usr/lib/${TOOL_NAME}"
    ## Templates path vars
    TEMPLATES_FULLPATH="/usr/share/${TOOL_NAME}"
    ## Log path vars
    LOG_FULLPATH="${HOME}/logs/${TOOL_NAME}"
    ## Set main config file vars
    CONF_MAIN_FILENAME="bdm-main.conf"
    CONF_MAIN_FULLPATH="/etc/${TOOL_NAME}"
    CONF_MAIN_FULLPATH_FILENAME="${CONF_MAIN_FULLPATH}/${CONF_MAIN_FILENAME}"
    CONF_USER_FULLPATH="${HOME}/.config/${TOOL_NAME}"
    CONF_USER_MAIN_FILENAME="bdm-user-main.conf"
    CONF_USER_MAIN_FULLPATH_FILENAME="${CONF_USER_FULLPATH}/${CONF_USER_MAIN_FILENAME}"
    ## Load libs
    . /usr/lib/berb-bash-libs/bbl_general_lib_${BBL_GENERAL_VERSION}
    . /usr/lib/berb-bash-libs/bbl_net_lib_${BBL_NET_VERSION}
    ## Config log
    fn_bbgl_config_log
    ## Config log level
    fn_bbgl_config_log_level $@
    ## Load global vars section from main config file
    section="global-vars"
    fn_bbgl_parse_file_section CONF_MAIN "${section}" "load_section"
    ## Check for --plugin flag
    fn_bbgl_check_args_search_flag "plugin" $@
    debug "FLAG_FOUND_VALUE = ${FLAG_FOUND_VALUE}"

    if [ -n "${FLAG_FOUND_VALUE}" ]; then
        plugin_enabled="${FLAG_FOUND_VALUE}"
	debug "plugin_enabled = ${plugin_enabled}"
    fi
}

fn_bdm_conf_file_install() {
    conf_full_path="$1"
    conf_filename="$2"
    conf_fullpath_filename="${conf_full_path}/${conf_filename}"
    ## If the conf file not exist copy from template
    [ ! -d "${conf_full_path}" ] && mkdir "${conf_full_path}" \
	&& debug "Creating dir: ${conf_full_path}"
	if [ ! -f "${conf_fullpath_filename}" ]; then
	cp "${TEMPLATES_FULLPATH}/${conf_filename}" "${conf_full_path}"
	debug "Copying user main conf file to: ${conf_full_path}"
    fi
}

fn_bdm_conf_file_ask_empty_vars() {
    conf_file_str="$1"
    section="$2"
    fn_bbgl_parse_file_section "${conf_file_str}" "${section}" "ask_empty_vars"
}

fn_bdm_conf_file_load() {
    conf_file_str="$1"
    section="$2"
    fn_bbgl_parse_file_section "${conf_file_str}" "${section}" "load_section"
}

fn_bdm_load_plugin() {
    if [ -n "${plugin_enabled}" ]; then
	. ${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_main.sh --run

        # printf '%s\n' ${arr_plugins_implemented[@]}
    else
	. ${LIBS_FULLPATH}/bdm_plugin_default.sh --run
        #fn_docker_menu_actions_basic
    fi
}


######################
## Docker functions ##
######################
fn_bdm_docker_main_menu() {
    arr_actions_base=( \
	"create container" \
	"remove container" \
	"start container" \
	"stop container" \
	"shell to container" \
	"command inside container" \
	"commit container" \
    )
}

fn_bdm_docker_container_config() {
    ## If no docker images found, set the default config
    docker_how_many_imgs=$(docker images | grep -c -v "TAG")""
    #if [ "${docker_how_many_imgs}" -eq "0" ]; then
	IMAGE_NAME="${IMAGE_BASE_NAME}"
	debug "CONTAINER_BASE_NAME = $CONTAINER_BASE_NAME"
        CONTAINER_NAME="$CONTAINER_BASE_NAME"
	IMAGE_TAG="${IMAGE_BASE_TAG}"
	#return 0
    #fi
    ## Search for container name
    container_exist=$(docker ps -a | grep "${CONTAINER_BASE_NAME}")

<< "DISABLED_NEEDS_REWRITE"
    ## If a docker image with "latest" on the tag name is found, set the commited config
    img_latest_tag="$(docker images | grep -v "TAG" | grep "${IMAGE_COMMIT_NAME}" \
	    | grep "latest" | awk '{print $1}')"
    if [ -n "${img_latest_tag}" ]; then
        IMAGE_NAME="${IMAGE_COMMIT_NAME}"
        CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
        #IMAGE_TAG="${IMAGE_COMMIT_TAG}"
        IMAGE_TAG="" ## Don't want a tag since we want "latest" as tag
	commited_img_found="True"
	return 0
    fi

    ## If no images with "latest" on tag name is found, set the default config
    img_base_exist="$(docker images | grep -v "TAG" | grep "${IMAGE_BASE_NAME}")"
    if [ -n "${img_base_exist}" ]; then
	IMAGE_NAME="${IMAGE_BASE_NAME}"
	IMAGE_TAG="${IMAGE_BASE_TAG}"
        CONTAINER_NAME="$CONTAINER_BASE_NAME"
	return 0
    fi

    error "An error occourred setting the CONTAINER_NAME var!"
DISABLED_NEEDS_REWRITE
}

fn_exit() {
    exit
}
fn_bdm_docker_menu_fzf() {
    fn_bssf_menu_fzf "action" "single"
    ACTION=$(echo "${item_selected}" | sed 's/ /_/g')
    debug "Action selected = \"${ACTION}\""
    ## If action = exit set exit=True and leave from function
    [ "${ACTION}" == "exit" ] && exit="True" && return
    ## If it's a plugin action set exit="True" and leave from function
    action_is_plugin=$(echo "${ACTION}" | grep "plugin")
    if [ -n "${action_is_plugin}" ]; then
	exit="True"
        debug "Action fn selected = \"${FN_ACTION}\""
	debug "Executing plugin exec function"
	fn_plugin_sub_exec
    else
        ## Call the docker action
        FN_ACTION="fn_bdm_docker_${ACTION}"
        [ -z "${ACTION}" ] && error "Action selection failed!"
        ## Crida la fn_action_ corresponent
        debug "Action fn selected = \"${FN_ACTION}\""
        debug "Calling function \"${FN_ACTION}\""
        eval ${FN_ACTION}
    fi
}

fn_bdm_docker_multiarch_enable() {
    ${SUDO} apt-get update && apt-get install -y qemu-user-static
    ${SUDO} dpkg --add-architecture ${target_arch}
    arr_apt_pkgs_cross_arm64=( "gcc-${cross_arch}-linux-gnu" "g++-${cross_arch}-linux-gnu" \
	                       "libc6-${target_arch}-cross" )
    arr_packages=( ${arr_apt_pkgs_cross_arm64[@]} ) && fn_bdm_docker_apt_install_pks
    #apt-get install binfmt-support

    ## Enable multiarch in docker as suggested in the official Droidian porting guide
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    sleep 5
}

fn_bdm_docker_create_container() {
# Creates the container
    info "CONTAINER_NAME = ${CONTAINER_NAME}"
    info "IMAGE_NAME:TAG = ${IMAGE_NAME}:${IMAGE_TAG}"
    pause "Pausa..."

    CONTAINER_EXISTS=$(docker ps -a | grep ${CONTAINER_NAME})
    img_commited_exist=$(docker images | grep ${IMAGE_COMMIT_NAME})
    [ -n "${img_commited_exist}" ] && IMAGE_NAME="${IMAGE_COMMIT_NAME}" \
	&& IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"

    if [ -z "${CONTAINER_EXISTS}" ]; then
        INFO "Creating docker container \"${CONTAINER_NAME}\""
	info "using \"${IMAGE_NAME}:${IMAGE_TAG}\" image..." 
	if [ "${docker_mode}" == "default" ]; then
	    docker -v create --name ${CONTAINER_NAME} \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	elif [ "${docker_mode}" == "package" -a "${pkg_type}" == "droidian_adaptation" ]; then
	    docker -v create --name ${CONTAINER_NAME} \
	        -v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
		-v ${buildd_local_repo_fullpath}:/buildd/local-repo \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	elif [[ "${docker_mode}" == "kernel" \
            || ("${docker_mode}" == "package" && "${pkg_type}" == "debian_package") ]]; then
	    docker -v create --name ${CONTAINER_NAME} \
		-v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	else
	    abort "Docker mode not implemented"
	fi
	## Ask to start container
	ASK "Want to start the container? [ y|n ]: "
	[ "${answer}" == "y" ] && start_cont="True" && fn_bdm_docker_start_container
	## Ask to install apt packages inside the container
        fn_bdm_docker_apt_ask_if_install_pkgs_full

	info "Container created!"
    else
	info "Container already exists!" #&& exit 4
    fi
}

fn_bdm_docker_remove_container() {
    # Removes a the container
    CONTAINER_EXIST=$(docker ps -a | grep -c "$CONTAINER_NAME")
    CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    if [ "$CONTAINER_EXIST" -eq '0' ]; then
	info "Container $CONTAINER_NAME not exists..."
	echo
    else
	ASK "SURE to REMOVE container $CONTAINER_NAME [ yes | any-word ] ? "
    fi
    if [ "${answer}" == "yes" ]; then
 	info "Removing container..."
	fn_bdm_docker_stop_container
	docker rm $CONTAINER_ID
    else
	info "Container $CONTAINER_NAME will NOT be removed as user choice"
	echo
    fi
}

fn_bdm_docker_start_container() {
    IS_STARTED=$(docker ps -a | grep $CONTAINER_NAME | awk '{print $5}' | grep -c 'Up')
    if [ "$IS_STARTED" -eq "0" ]; then
	## Ask for enable multiarch support
	ASK "Want to start the docker multiarch compat? [ y|n ]: "
	[ "${answer}" == "y" ] && fn_bdm_docker_multiarch_enable
	## Start the container
        INFO "Starting container ${CONTAINER_NAME}"
	docker start $CONTAINER_NAME
    fi
}

fn_bdm_docker_stop_container() {
    INFO "Stopping container ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
}

fn_get_default_container_id() {
    # Search for original container id
    DEFAULT_CONT_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
}

fn_bdm_docker_commit_container() {
    clear
    INFO "INFO about commiting containers"
    info "UNDER REVISION"
    INFO "When the first commit is created, a new image from the base container is created"
    info "and a container with the commited name is created from te commited image"
    INFO "The next commits will be taken from the comitted container,"
    info "updatingd the image and recreating the container"
    PAUSE "Intro to continue..."

    ## Check if a container from a commited image exist.
    ## Case exist, create a new commit from commited container
    ## Otherwise create a commit from the base container.
    container_exist=$(docker ps -a | grep ${CONTAINER_COMMITED_NAME})
    if [ -n "${container_exist}" ]; then
        # Commit creation
        INFO "Creating another committed image \"$IMAGE_COMMIT_NAME\" from \"${CONTAINER_COMMITED_NAME}\" container..."
        info "Please be patient!!!"
        docker commit "${CONTAINER_COMMITED_NAME}" "${IMAGE_COMMIT_NAME}:${IMAGE_COMMIT_TAG}_latest"
        docker stop "${CONTAINER_COMMITED_NAME}"
        docker rm "${CONTAINER_COMMITED_NAME}"
	# Create new container from commit image.
	CONTAINER_NAME="${CONTAINER_COMMITED_NAME}"
	IMAGE_NAME="${IMAGE_COMMIT_NAME}"
	IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"
	INFO "Recreating ${CONTAINER_NAME} container from committed image ${IMAGE_NAME}:${IMAGE_TAG}..."
	fn_bdm_docker_create_container
	INFO "Creation of another commit and container with the current state is finished!"
	echo
    else
        # Commit creation
        INFO "Creating the first committed image \"$IMAGE_COMMIT_NAME\" from \"${CONTAINER_BASE_NAME}\" container..."
        echo "Please be patient!!!"
        docker commit "${CONTAINER_BASE_NAME}" "${IMAGE_COMMIT_NAME}:${IMAGE_COMMIT_TAG}_latest"
	# Create new container from commit image.
	CONTAINER_NAME="${CONTAINER_COMMITED_NAME}"
	IMAGE_NAME="${IMAGE_COMMIT_NAME}"
	IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"
	INFO "Creating new ${CONTAINER_NAME} container from committed imag ${IMAGE_NAME}:${IMAGE_TAG}..."
	fn_bdm_docker_create_container
	INFO "Creation of the first commit and container with the current state is finished!"
	echo
    fi
}	

fn_bdm_docker_shell_to_container() {
    docker exec -it $CONTAINER_NAME bash --login
}

fn_bdm_docker_cmd_inside_container() {
    docker exec -it ${CONTAINER_NAME} $@
}

fn_cp_to_container() {
    docker cp ${copy_src} ${CONTAINER_NAME}:${copy_dst}
}

fn_cp_from_container() {
    docker cp ${CONTAINER_NAME}:${copy_src} ${copy_dst}
}

################################
## APT on container functions ##
################################
fn_bdm_docker_apt_ask_if_install_pkgs_full() {
	#Ask to install required apt packages
	[ "${start_cont}" == "True" ] \
	    && ASK "Want to install the required apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && req_inst="True" \
            && arr_packages=( ${arr_apt_pkgs_req[@]} ) && fn_bdm_docker_apt_install_pks
	#Ask to install basic apt packages
	[ "${req_inst}" == "True" ] \
	    && ASK "Want to install the basic apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && base_inst="True" \
	    && arr_packages=( ${arr_apt_pkgs_base[@]} ) && fn_bdm_docker_apt_install_pks
	#Ask to install extra apt packages
	[ "${base_inst}" == "True" ] \
	    && ASK "Want to install the extra apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] \
	    && arr_packages=( ${arr_apt_pkgs_extra[@]} ) && fn_bdm_docker_apt_install_pks
}

fn_bdm_docker_apt_install_pks() {
    fn_bdm_docker_cmd_inside_container apt-get update
    fn_bdm_docker_cmd_inside_container apt-get install -y ${arr_packages[@]}
}
fn_bdm_docker_apt_upgrade_install_pks() {
    fn_bdm_docker_cmd_inside_container apt-get update
    fn_bdm_docker_cmd_inside_container apt-get upgrade -y
    fn_bdm_docker_cmd_inside_container apt-get install -y ${arr_packages[@]}
}
############################
## Config build functions ##
############################
fn_print_vars() {
    ## Prints kernel paths
    echo && echo "Config defined:"
    echo && echo "KERNEL_NAME $KERNEL_NAME"
    echo "KERNEL_BASE_VERSION = $KERNEL_BASE_VERSION"
    echo "KERNEL_BASE_VERSION_SHORT = $KERNEL_BASE_VERSION_SHORT"
    echo "KERNEL_DIR = $KERNEL_DIR"
    echo "DEVICE_DEFCONFIG_FILE = $DEVICE_DEFCONFIG_FILE"
    echo "KERNEL_BUILD_OUT_KOBJ_PATH =$KERNEL_BUILD_OUT_KOBJ_PATH"
    echo "PACKAGES_DIR = $PACKAGES_DIR"
    echo "KERNEL_BUILD_OUT_DEBS_PATH = $KERNEL_BUILD_OUT_DEBS_PATH"
    echo "KERNEL_BUILD_OUT_DEBIAN_PATH = $KERNEL_BUILD_OUT_DEBIAN_PATH"
    echo "KERNEL_BUILD_OUT_LOGS_PATH = $KERNEL_BUILD_OUT_LOGS_PATH"
    echo "KERNEL_BUILD_OUT_OTHER_PATH = $KERNEL_BUILD_OUT_OTHER_PATH"
    echo "DEVICE_VENDOR = $DEVICE_VENDOR"
    echo "DEVICE_FULL_NAME = $DEVICE_FULL_NAME"
    echo "DEVICE_MODEL = $DEVICE_MODEL"
    echo "DEVICE_ARCH = $DEVICE_ARCH"
    read -p "Continue..."
} 

############################
## Start script execution ##
############################
## Configuration
fn_bdm_global_conf $@
fn_bbnl_ip_forward_activa
fn_bbgl_configura_sudo
fn_bbgl_check_bash_ver
## Load config files
fn_bdm_conf_file_install "${CONF_USER_FULLPATH}" "${CONF_USER_MAIN_FILENAME}"
fn_bdm_conf_file_ask_empty_vars "CONF_USER_MAIN" "global-vars"
fn_bdm_conf_file_load "CONF_USER_MAIN" "global-vars"
## Load the default or tagged as script argument plugin
fn_bdm_load_plugin

