#!/bin/bash

## Script to manage docker containers

# Upstream-Name: berb-droidian-build-docker-mgr
# Source: https://github.com/droidian-berb/berb-droidian-build-docker-mgr
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
TOOL_NAME="$(basename ${BASH_SOURCE[0]} | awk -F'.' '{print $1}')"
#TOOL_VERSION="2.0.0.1"
#TOOL_CHANNEL="develop"
TESTED_BASH_VER='5.2.15'


####################
## Info functions ##
####################

info() { echo "$*"; }
INFO() { echo; echo "$*"; }
warn() { echo "$*"; }
WARN() { echo; echo "$*"; }
debug() { echo "$*"; }
DEBUG() { echo; echo "$*"; }
abort() { echo "$*"; exit 10; }
ABORT() { echo; echo "$*"; exit 10; }
error() { echo "$*"; exit 1; }
ERROR() { echo; echo "$*"; exit 1; }
missatge() {  echo "$*"; }
missatge_return() { echo; echo "$*"; return 0; }
ask() { read -p "$*" answer; }
ASK() { echo; read -p "$*" answer; }
pause() { read -p "$*"; }
PAUSE() { echo; read -p "$*"; }

#######################
## Control functions ##
#######################
fn_check_bash_ver() {
    bash_ver=$(bash --version | head -n 1 \
	| awk '{print $4}' | awk -F'(' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')
    IFS_BKP=$IFS
    IFS='.' read -r vt_major vt_minor vt_patch <<< "${TESTED_BASH_VER}"
    IFS='.' read -r v_major v_minor v_patch <<< "${bash_ver}"
    IFS=$IFS_BKP
    if [[ $v_major -lt $vt_major ]] || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -lt $vt_minor ]]) || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -eq $vt_minor ]] \
	       && [[ $v_patch -lt $vt_patch ]]); then
    	clear
        WARN "Bash version detected is lower than the tested version"
        warn "If errors are found, try upgrading bash to \"${TESTED_BASH_VER}\" version"
	pause "Press Inro to continue"
    else
        INFO "Bash version requirements are fine"
    fi
}


######################
## Config functions ##
######################
fn_configura_sudo() { [ "$USER" != "root" ] && SUDO='sudo'; }

fn_ip_forward_activa() {
    ## Activa ipv4_forward (requerit per xarxa containers) i reinicia docker.
    ## És la primera funció que crida l'script
    FORWARD_ES_ACTIVAT=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$FORWARD_ES_ACTIVAT" -eq "0" ]; then
  	echo "" && echo "Activant ip4_forward..."
	${SUDO} sysctl -w net.ipv4.ip_forward=1
	${SUDO} systemctl restart docker
    else
	echo && echo "ip4_forward prèviament activat!"
    fi
}

######################
## Docker functions ##
######################
fn_docker_global_config() {
    ## Docker constants
    CONTAINER_BASE_NAME="droidian-build-env-${package_name}"
    IMAGE_BASE_NAME='quay.io/droidian/build-essential'
    IMAGE_BASE_TAG="${droidian_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="droidian-berb-build-env-${package_name}"
    IMAGE_COMMIT_NAME='berb/build-essential'
    IMAGE_COMMIT_TAG="${droidian_suite}-${host_arch}"

    ## If no docker images found, set the default config
    docker_how_many_imgs=$(docker images | grep -c -v "TAG")""
    if [ "${docker_how_many_imgs}" -eq "0" ]; then
	IMAGE_NAME="${IMAGE_BASE_NAME}"
        CONTAINER_NAME="$CONTAINER_BASE_NAME"
	IMAGE_TAG="${IMAGE_BASE_TAG}"
	return 0
    fi

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

    ERROR "An error occourred setting the CONTAINER_NAME var!"
}

fn_docker_multiarch_enable() {
    ## Enable multiarch in docker as suggested in the official porting guide
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
}

fn_create_container() {
# Creates the container
    DEBUG "CONTAINER_NAME = $CONTAINER_NAME"
    pause "Pausa..."

    CONTAINER_EXISTS=$(docker ps -a | grep -c ${CONTAINER_NAME})
    img_commited_exist=$(docker images | grep ${IMAGE_COMMIT_NAME})
    [ -n "${img_commited_exist}" ] && IMAGE_NAME="${IMAGE_COMMIT_NAME}" \
	&& IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"

    if [ "${CONTAINER_EXISTS}" -eq "0" ]; then
        INFO "Creating docher container \"${CONTAINER_NAME}\""
	info "using \"${IMAGE_NAME}:${IMAGE_TAG}\" imgage..." 
	if [ "${docker_mode}" == "package" -a "${pkg_type}" == "droidian_adapt" ]; then
	    docker -v create --name ${CONTAINER_NAME} \
	        -v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
		-v ${buildd_local_repo_fullpath}:/buildd/local-repo \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	elif [[ "${docker_mode}" == "kernel" \
            || ("${docker_mode}" == "package" && "${pkg_type}" == "standard_pkg") ]]; then
	    docker -v create --name ${CONTAINER_NAME} \
		-v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	else
	    ABORT "Docker mode not implemented"
	fi
	## Ask to start container
	ASK "Want to start the container? [ y|n ]: "
	[ "${answer}" == "y" ] && start_cont="True" && fn_start_container
	#Ask to install required apt packages
	[ "${start_cont}" == "True" ] \
	    && ASK "Want to install the required apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && req_inst="True" && fn_install_apt_req
	#Ask to install basic apt packages
	[ "${req_inst}" == "True" ] \
	    && ASK "Want to install the basic apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && base_inst="True" && fn_install_apt_base
	#Ask to install extra apt packages
	[ "${base_inst}" == "True" ] \
	    && ASK "Want to install the extra apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && fn_install_apt_extra

	INFO "Container created!"
    else
	INFO "Container already exists!" && exit 4
    fi
}

fn_remove_container() {
    # Removes a the container
    CONTAINER_EXIST=$(docker ps -a | grep -c "$CONTAINER_NAME")
    CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    if [ "$CONTAINER_EXIST" -eq '0' ]; then
	INFO "Container $CONTAINER_NAME not exists..."
	echo
    else
	PAUSE "SURE to REMOVE container $CONTAINER_NAME [ yes | any-word ] ? " RM_CONT
    fi
    if [ "$RM_CONT" == "yes" ]; then
 	INFO "Removing container..."
	fn_stop_container
	docker rm $CONTAINER_ID
    else
	INFO "Container $CONTAINER_NAME will NOT be removed as user choice"
	echo
    fi
}

fn_start_container() {
    IS_STARTED=$(docker ps -a | grep $CONTAINER_NAME | awk '{print $5}' | grep -c 'Up')
    if [ "$IS_STARTED" -eq "0" ]; then
	## Ask for enable multiarch support
	ASK "Want to start the docker multiarch compat? [ y|n ]: "
	[ "${answer}" == "y" ] && fn_docker_multiarch_enable
	## Start the container
        INFO "Starting container ${CONTAINER_NAME}"
	docker start $CONTAINER_NAME
    fi
}

fn_stop_container() {
    INFO "Stopping container ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
}

fn_get_default_container_id() {
    # Search for original container id
    DEFAULT_CONT_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
}

fn_commit_container() {
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
	fn_create_container
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
	fn_create_container
	INFO "Creation of the first commit and container with the current state is finished!"
	echo
    fi
}	

fn_shell_to_container() {
    docker exec -it $CONTAINER_NAME bash --login
}

fn_cmd_on_container() {
    docker exec -it ${CONTAINER_NAME} ${CMD}
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
fn_install_apt() {
    packages="$1"
    APT_UPDATE="apt-get update"
    APT_UPGRADE="apt-get upgrade -y"
    APT_INSTALL="apt-get install -y "${packages}""
    CMD="$APT_UPDATE" && fn_cmd_on_container
    CMD="$APT_UPGRADE" && fn_cmd_on_container
    CMD="$APT_INSTALL" && fn_cmd_on_container
}

fn_install_apt_req() {
    APT_INSTALL_REQ="droidian-apt-config droidian-archive-keyring"
    fn_install_apt "${APT_INSTALL_REQ}"
}

fn_install_apt_base() {
    APT_INSTALL_BASE="vim git wget less bash-completion rsync net-tools"
    fn_install_apt "${APT_INSTALL_BASE}"
}

fn_install_apt_extra() {
    ## APT_INSTALL_EXTRA is defined on the pachage type (kernel, package, etc) docker config sections
    fn_install_apt "${APT_INSTALL_EXTRA}"
}

############################
## Config build functions ##
############################
fn_dir_is_git() {
    ## Abort if no .git directori found
    [ ! -d ".git" ] && abort "The current dir should be a git repo!"
}

fn_device_info_load() {
    ## Check file in the user home .config dir
    device_info_filename="device_info.sh"
    dev_info_template_fullpath="/usr/lib/${TOOL_NAME}"
    template="${dev_info_template_fullpath}/${device_info_filename}"
    dev_info_install_fullpath="${HOME}/.config/${TOOL_NAME}"
    install_dir="${dev_info_install_fullpath}"
    install_file="${install_dir}/${device_info_filename}"
    [ ! -d "${install_dir}" ] && mkdir -v "${install_dir}"
    [ ! -f "${install_file}" ] && cp -v "${template}" "${install_dir}"

    ## Search for empty vars in the device config file
    for var in $(cat "${install_file}"); do
        var_not_set=$(echo "${var}" | grep -v "#" | grep -v "=\"" | grep "=")
	if [ -n "${var_not_set}" ]; then
	   info "var_not_set = $var_not_set"
	   ask "\"${var_not_set}\" name is not configured. Please type it: "
           [ -n "${answer}" ] && sed -i \
	       "s/${var_not_set}/${var_not_set}\"${answer}\"/g" "${install_file}"
	fi
    done
    source "${dev_info_install_fullpath}/${device_info_filename}"
}

fn_pkg_source_type_detection() {
    ## Save start fullpath
    START_DIR=$(pwd)
    # Cerca un arxiu README de linux kernel
    if [ -e "$START_DIR/README" ]; then
	## check for git dir
	fn_dir_is_git # Aborts if not
	## Check if is kernel
        IS_KERNEL=$(cat $START_DIR/README | head -n 1 | grep -c "Linux kernel")
        [ "${IS_KERNEL}" -eq '0' ] \
	    && ABORT "No Linux kernel README file found in current dir."
	INFO "Kernel source dir detected!"
	docker_mode="kernel"
	## Call kernel source config
	fn_docker_config_kernel_source
    elif [ -e "${START_DIR}/sparse" ]; then
        ## check for git dir
        fn_dir_is_git # Aborts if not
	## Check for debian control
	[ ! -f "debian/control" ] && abort "debian control file not found!"
	## Set docker mode
	docker_mode="package"

        ## Get the package name from debian control
        package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')

	## Get the package type
	pkg_type=""
	[ -z "${pkg_type}" ] \
	    && [ -n "$(echo "${package_name}" | grep "^adaptation")" ] \
	    && pkg_type="droidian_adapt"
	[ -z "${pkg_type}" ] \
	    && pkg_type="standard_pkg"
	[ -z "${pkg_type}" ] \
	    && abort "Not supported sparse dir detected!"

	## Call droidian build tools configurer for packages
	source /usr/lib/${TOOL_NAME}/berb-build-droidian-package.sh
	fn_docker_config_droidian_build_tools_package
    else
        abort "Not supported package dir found!"
    fi
}

fn_create_outputs_backup() {
    ## TODO: Needs a full revision
    ## Moving output deb files to $PACKAGES_DIR/debs
    echo && echo Moving output deb files to $KERNEL_BUILD_OUT_DEBS_PATH
    mv $PACKAGES_DIR/*.deb $KERNEL_BUILD_OUT_DEBS_PATH
    ## Moving output log files to $PACKAGES_DIR/logs
    echo && echo Moving output log files to $KERNEL_BUILD_OUT_LOGS_PATH
    mv $PACKAGES_DIR/*.build* $KERNEL_BUILD_OUT_LOGS_PATH

    ## Copyng out/KERNL_OBJ relevant files to $PACKAGES_DIR/other..."
    arr_OUT_DIR_FILES=( \
	'boot.img' 'dtbo.img' 'initramfs.gz' 'recovery*' 'target-dtb' 'vbmeta.img' 'arch/arm64/boot/Image.gz' )
    echo && echo "Copyng out/KERNL_OBJ relevant files to $PACKAGES_DIR/other..."
    cd $KERNEL_BUILD_OUT_KOBJ_PATH
    for i in ${arr_OUT_DIR_FILES[@]}; do
 	cp -a $i $KERNEL_BUILD_OUT_OTHER_PATH
    done
    cd $START_DIR

    ## Copyng device defconfig file to PACKAGES_DIR..."
    echo && echo " Copyng $DEVICE_DEFCONFIG_FILE file to $PACKAGES_DIR..."
    cp -a "arch/$DEVICE_ARCH/configs/$DEVICE_DEFCONFIG_FILE" $PACKAGES_DIR

    ## Copyng debian dir to final outputs dir..."
    arr_DEBIAN_FILES=( \
	'debian/copyright' 'debian/compat' 'debian/kernel-info.mk' 'debian/rules' \
	'debian/source' 'debian/initramfs-overlay' )
    echo && echo "Copying debian dir to $KERNEL_BUILD_OUT_DEBS_PATH..."
    cp -a debian/* $KERNEL_BUILD_OUT_DEBS_PATH/
    for i in ${arr_DEBIAN_FILES[@]}; do
 	cp -a $KERNEL_BUILD_OUT_DEBS_PATH/$i debian/
    done
    ## Make a tar.gz from PACKAGES_DIR
    echo && echo "Creating $BACKUP_FILE_NOM from $PACKAGES_DIR"
    cd $SOURCES_FULLPATH
    tar zcvf $BACKUP_FILE_NOM $PACKAGES_DIR
    if [ "$?" -eq '0' ]; then
 	echo && echo "Backup $BACKUP_FILE_NOM created on the parent dir"
    else
	echo && echo "Backup $BACKUP_FILE_NOM failed!!!"
    fi
    cd $START_DIR
}

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

fn_action_prompt() {
## Function to get a action
    INFO "Action is required:"
    INFO "  1 - Create container            2 - Remove container"
    info "  3 - Start container             4 - Stop container"
    info "  5 - Commit container"
    info "  7 - Shell to container          8 - Command to container"
    INFO " 09 - Config Droidian kernel     10 - Build kernel on container"
    info " 11 - Config package             12 - Build package on container"
    info " 13 - Config adaptation          14 - Build adaptation on container"
    #INFO " 6 - Install required apt pkgs on container"
    #INFO  "20 - Backup kernel build output relevant files"
    ASK "Select an option: "
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
	9)
	    ACTION="config-droidian-kernel"
	    ;;
	10)
	    ACTION="build-kernel-on-container"
	    ;;
	11)
	    ACTION="config-droidian-package"
	    ;;
	12)
	    ACTION="build-package-on-container"
	    ;;
	13)
	    ACTION="config-droidian-adaptation"
	    ;;
	14)
	    ACTION="build-adaptation-on-container"
	    ;;
	20)
	    ACTION="create-outputs-backup"
	    ;;
	*)
	    echo "" && echo "Option not implemented!" && exit 1
	    ;;
	esac
}

############################
## Start script execution ##
############################
## Configuration
fn_ip_forward_activa
fn_configura_sudo
fn_check_bash_ver
fn_pkg_source_type_detection
fn_docker_global_config
fn_action_prompt
#fn_set_container_commit_if_exists

#fn_print_vars
#echo

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
elif [ "$ACTION" == "install-apt-extra" ]; then
    fn_install_apt_extra
elif [ "$ACTION" == "commit-container" ]; then
    fn_commit_container
elif [ "$ACTION" == "config-droidian-kernel" ]; then
    fn_kernel_config_droidian
elif [ "$ACTION" == "build-kernel-on-container" ]; then
    fn_build_kernel_on_container
elif [ "$ACTION" == "config-droidian-package" ]; then
    fn_config
elif [ "$ACTION" == "build-package-on-container" ]; then
    fn_build_package_on_container
elif [ "$ACTION" == "config-droidian-adaptation" ]; then
    fn_config
elif [ "$ACTION" == "build-adaptation-on-container" ]; then
    fn_build_adaptation_on_container
elif [ "$ACTION" == "create-outputs-backup" ]; then
    fn_create_outputs_backup
else
    echo "SCRIPT END: Action not implemented."
fi

