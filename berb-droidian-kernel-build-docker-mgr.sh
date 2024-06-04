#!/bin/bash

# Upstream-Name: berb-droidian-kernel-build-docker-mgr
# Source: https://gitlab.com/droidian-berb/berb-droidian-kernel-build-docker-mgr
  ## Script that manages a custom docker container with Droidian build environment

# Copyright (C) 2022 Berbascum <berbascum@ticv.cat>
# All rights reserved.

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

################
## Changelog: ##
################
  # To do:
    # Add cmd params support
    # Before compiling, script asks for remove out dir?

  # v_1.0.0-3: name changed from "droidian-manage-docker-container to "berb-droidian-kernel-build-docker-mgr"
    # New: fn_configura_sudo
    # New: fn_build_env_base_paths_config
    # New: Implemented kernel path auto detection
    # New: Implemented multiple container with different mounted kernel sources
    # New: Basic check to determine if the start dir is a kernel source root dir and a git repo too.
    # New: fn_create_outputs_backup: NOT DONE: After compilation, script archives most output relevant files and archive them to tar.gz
    # New: fn_remove_container
    # New Check the minimal recomended bash version"

  # v_0.0.2-1
    # New: fn_ip_forward_activa

  # v_0.0.2
    # Added build-kernel-on-container feature 
      # Before compiling, script asks for remove out dir.
    # Added feature to enable/disable download build deps in kernel-info.mk
    # Improvements and bug fixes  in commit_container function.
    # Improvements in commit_container function.
    
  # v_0.0.1
   # Features:
    # Create container: Create container from docker image:
      # quay.io/droidian/build-essential:bookworm-amd64
    # Basic container management
    # Open a bash shell inside container
    # Commit container:
      # Creates a new image with custom modifications, and 
      # Then creates a new container from it.
      # Only one commit is implemented.
    # Install build env dependences with apt-get
    # Custom configurations on container: To do.

  # v_0.0.0
    # Starting version. Just create a conbtainer from Droidian build-essential image.
    

#################
## Header vars ##
#################
TOOL_NAME="berb-droidian-kernel-build-docker-mgr"
TOOL_VERSION="1.0.0.3"
TOOL_BRANCh="release/${TOOL_VERSION}"
TESTED_BASH_VER='5.2.15'

# Not used yet by this script:
# VERSIO_SCRIPTS_SHARED_FUNCS="0.2.1"

######################
## Global functions ##
######################
fn_configura_sudo() {
    if [ "$USER" != "root" ]; then SUDO='sudo'; fi
}

abort() {
    echo; echo "$*"
    exit 1
}

info() {
    echo; echo "$*"
}

ask() {
    echo; read -p "$*" answer
}

pause() {
    echo; read -p "$*"
}
missatge() {
    echo; echo "$*"
}

missatge_return() {
    echo; echo "$*"
    return 0
}

fn_check_bash_ver() {
    bash_ver=$(bash --version | head -n 1 | awk '{print $4}' | awk -F'(' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')
    IFS_BKP=$IFS
    IFS='.' read -r vt_major vt_minor vt_patch <<< "${TESTED_BASH_VER}"
    IFS='.' read -r v_major v_minor v_patch <<< "${bash_ver}"
    IFS=$IFS_BKP
    if [[ $v_major -lt $vt_major ]] || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -lt $vt_minor ]]) || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -eq $vt_minor ]] && [[ $v_patch -lt $vt_patch ]]); then
    	clear
        echo; echo "Bash version detected is lower than tested version"
        echo "If getting errors during script execution, try upgrading bash to \"${TESTED_BASH_VER}\" version"
	echo; read -p "Press Inro to continue"
    else
        echo; echo "Bash version requirements are fine"
    fi
}


######################
## Config functions ##
######################
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

    ## If no docker images found, set default config
    docker_how_many_imgs=$(docker images | grep -c -v "TAG")""
    if [ "${docker_how_many_imgs}" -eq "0" ]; then
	IMAGE_NAME="${IMAGE_BASE_NAME}"
        CONTAINER_NAME="$CONTAINER_BASE_NAME"
	IMAGE_TAG="${IMAGE_BASE_TAG}"
	return 0
    fi

    ## If docker images found, search for a commited image with tag=latest
    img_latest_tag="$(docker images | grep -v "TAG" | grep "${IMAGE_COMMIT_NAME}" \
	    | grep "latest" | awk '{print $1}')"
    if [ -n "${img_latest_tag}" ]; then
        IMAGE_NAME="${IMAGE_COMMIT_NAME}"
        CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
        #IMAGE_TAG="${IMAGE_COMMIT_TAG}"
        IMAGE_TAG="" ## Don't want a tag since we wnt "latest" as tag
	commited_img_found="True"
	return 0
    fi

    ## If docker images found but there isn't latest comit, and the default image exist, set default config
    img_base_exist="$(docker images | grep -v "TAG" | grep "${IMAGE_BASE_NAME}")"
    if [ -n "${img_base_exist}" ]; then
	IMAGE_NAME="${IMAGE_BASE_NAME}"
	IMAGE_TAG="${IMAGE_BASE_TAG}"
        CONTAINER_NAME="$CONTAINER_BASE_NAME"
	return 0
    fi

    abort "An error occourred setting the CONTAINER_NAME var!"
}

fn_docker_multiarch_enable() {
	## Enable multiarch in docker as suggested in the official porting guide
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
}

fn_create_container() {
# Creates the container
    echo; echo "CONTAINER_NAME = $CONTAINER_NAME"
    read -p "Pausa..."

    CONTAINER_EXISTS=$(docker ps -a | grep -c ${CONTAINER_NAME})
    img_commited_exist=$(docker images | grep ${IMAGE_COMMIT_NAME})
    [ -n "${img_commited_exist}" ] && IMAGE_NAME="${IMAGE_COMMIT_NAME}" && IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"

    if [ "${CONTAINER_EXISTS}" -eq "0" ]; then
        info "Creating docker container \"${CONTAINER_NAME}\" using \"${IMAGE_NAME}:${IMAGE_TAG}\" img..." 
	if [ "${docker_mode}" == "package" -a "${pkg_type}" == "droidian_adapt" ]; then
	    docker -v create --name ${CONTAINER_NAME} \
	        -v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
		-v ${buildd_local_repo_fullpath}:/buildd/local-repo \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	elif [[ "${docker_mode}" == "kernel" \
		|| ("${docker_mode}" == "package" && "${pkg_type}" == "standard_pkg") ]] ; then
	    docker -v create --name ${CONTAINER_NAME} \
		-v ${buildd_fullpath}:/buildd \
		-v ${buildd_sources_fullpath}:/buildd/sources \
	        -i -t "${IMAGE_NAME}:${IMAGE_TAG}"
	else
	    abort "Docker mode not implemented"
	fi
	## Ask to start container
	ask "Want to start the container? [ y|n ]: "
	[ "${answer}" == "y" ] && start_cont="True" && fn_start_container
	#Ask to install required apt packages
	[ "${start_cont}" == "True" ] && ask "Want to install the required apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && req_inst="True" && fn_install_apt_req
	#Ask to install basic apt packages
	[ "${req_inst}" == "True" ] && ask "Want to install the basic apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && base_inst="True" && fn_install_apt_base
	#Ask to install extra apt packages
	[ "${base_inst}" == "True" ] && ask "Want to install the extra apt packages? [ y|n ]: "
	[ "${answer}" == "y" ] && fn_install_apt_extra

	info "Container created!"
    else
	info "Container already exists!" && exit 4
    fi
}

fn_remove_container() {
    # Removes a the container
    CONTAINER_EXIST=$(docker ps -a | grep -c "$CONTAINER_NAME")
 	CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    if [ "$CONTAINER_EXIST" -eq '0' ]; then
	echo && echo "Container $CONTAINER_NAME not exists..."
	echo
    else
	echo && read -p "SURE to REMOVE container $CONTAINER_NAME [ yes | any-word ] ? " RM_CONT
    fi
    if [ "$RM_CONT" == "yes" ]; then
 	echo && echo "Removing container..."
	fn_stop_container
	docker rm $CONTAINER_ID
    else
	echo && echo "Container $CONTAINER_NAME will NOT be removed as user choice"
	echo
    fi
}

fn_start_container() {
    IS_STARTED=$(docker ps -a | grep $CONTAINER_NAME | awk '{print $5}' | grep -c 'Up')
    if [ "$IS_STARTED" -eq "0" ]; then
	## Ask for enable multiarch support
	ask "Want to start the docker multiarch compat? [ y|n ]: "
	[ "${answer}" == "y" ] && fn_docker_multiarch_enable
	## Start the container
        info "Starting container ${CONTAINER_NAME}"
	docker start $CONTAINER_NAME
    fi
}

fn_stop_container() {
    info "Stopping container ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
}

fn_get_default_container_id() {
    # Search for original container id
    DEFAULT_CONT_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
}

fn_commit_container() {
    clear
    echo; echo "INFO about commiting containers"
    echo; echo "UNDER REVISION"
    echo; echo "When the first commit is created, a new image from the base container is created"
    echo "and a container with the container commited name is created from te commited image"
    echo; echo "The next commits will be taken from the comitted container, updatingd the image and"
    echo "recreating the container"
    echo; read -p "Intro to continue..."

    ## Check if a container from a commited image exist. Case exist, create a new commit from commited container
    ## Otherwise create a commit from the base container.
    container_exist=$(docker ps -a | grep ${CONTAINER_COMMITED_NAME})
    if [ -n "${container_exist}" ]; then
        # Commit creation
        echo && echo "Creating another committed image \"$IMAGE_COMMIT_NAME\" from \"${CONTAINER_COMMITED_NAME}\" container..."
        echo "Please be patient!!!"
        docker commit "${CONTAINER_COMMITED_NAME}" "${IMAGE_COMMIT_NAME}:${IMAGE_COMMIT_TAG}_latest"
        docker stop "${CONTAINER_COMMITED_NAME}"
        docker rm "${CONTAINER_COMMITED_NAME}"
	# Create new container from commit image.
	CONTAINER_NAME="${CONTAINER_COMMITED_NAME}"
	IMAGE_NAME="${IMAGE_COMMIT_NAME}"
	IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"
	echo && echo "Recreating ${CONTAINER_NAME} container from committed image ${IMAGE_NAME}:${IMAGE_TAG}..."
	fn_create_container
	echo && echo Creation of another commit and container with the current state is finished!
	echo
    else
        # Commit creation
        echo && echo "Creating the first committed image \"$IMAGE_COMMIT_NAME\" from \"${CONTAINER_BASE_NAME}\" container..."
        echo "Please be patient!!!"
        docker commit "${CONTAINER_BASE_NAME}" "${IMAGE_COMMIT_NAME}:${IMAGE_COMMIT_TAG}_latest"
	# Create new container from commit image.
	CONTAINER_NAME="${CONTAINER_COMMITED_NAME}"
	IMAGE_NAME="${IMAGE_COMMIT_NAME}"
	IMAGE_TAG="${IMAGE_COMMIT_TAG}_latest"
	echo && echo "Creating new ${CONTAINER_NAME} container from committed imag ${IMAGE_NAME}:${IMAGE_TAG}..."
	fn_create_container
	echo && echo Creation of the first commit and container with the current state is finished!
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

fn_install_apt() {
    packages="$1"
    APT_UPDATE="apt-get update"
    APT_UPGRADE="apt-get upgrade -y"
    APT_INSTALL="apt-get install -y "${packages}""
    CMD="$APT_UPDATE" && fn_cmd_on_container
    CMD="$APT_UPGRADE" && fn_cmd_on_container
    CMD="$APT_INSTALL" && fn_cmd_on_container
}


############################
## Kernel build functions ##
############################
fn_dir_is_git() {
    ## Abort if no .git directori found
    [ ! -d ".git" ] && abort "The current dir should be a git repo!"
}

fn_device_info_load() {
    ## Load device info vars
    [ ! -f "device_info" ] && abort "The device_info file is required!"
    source device_info
}

fn_build_env_base_paths_config() {
	## Save start fullpath
    START_DIR=$(pwd)
    # Cerca un aerxiu README de linux kernel
    if [ -e "$START_DIR/README" ]; then
	## check for git dir
	fn_dir_is_git # Aborts if not
	## Check if is kernel
        IS_KERNEL=$(cat $START_DIR/README | head -n 1 | grep -c "Linux kernel")
        [ "${IS_KERNEL}" -eq '0' ] && abort "No Linux kernel README file found in current dir."
	info "Kernel source dir detected!"
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

	## Get the package type
	pkg_type=""
	[ -z "${pkg_type}" ] \
		&& [ -n "$(echo "${package_name}" | grep "^adaptation")" ] && pkg_type="droidian_adapt"
	[ -z "${pkg_type}" ] \
		&& pkg_type="standard_pkg"
	[ -z "${pkg_type}" ] \
		&& abort "Not supported sparse dir detected!"

	## Call droidian build tools configurer for packages
	fn_docker_config_droidian_build_tools_package
    else
        abort "Not supported package dir found!"
    fi
}

fn_docker_config_droidian_build_tools_package() {
    APT_INSTALL_EXTRA="releng-tools"
    
    ## Load device_info vars
    fn_device_info_load

    # Set package paths
    SOURCES_FULLPATH="${START_DIR}"
    ## Get the package name from debian control
    package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')

    # Get package dirname as current dir name
    pkg_dirname=$(basename ${SOURCES_FULLPATH})

    ## Call configurer for the detected package type
    fn_docker_config_${pkg_type}_source
}

fn_docker_config_standard_pkg_source() {
    ## TODO implement package_version var
    #
    #
    #
    AQUI
    #
    #
    OUTPUT_FULLPATH="${SOURCES_FULLPATH}/out-${package_name}-${package_version}"
    PACKAGES_DIR="${OUTPUT_FULLPATH}"
    buildd_fullpath="${PACKAGES_DIR}" 
    buildd_sources_fullpath="${SOURCES_FULLPATH}"
    ## Create the output dir
    [ -d "$PACKAGES_DIR" ] || mkdir -v $PACKAGES_DIR
}

fn_check_for_droidian_build_tools() {
	echo "TODO"
	# AQUI
}
fn_docker_config_droidian_adapt_source() {
## The build adaptation process consists on thre  parts:
# config: (outside docker) The adaptation scripts are used to configure the build env
 # build: (on docker) execute releng-build-package on a container
 # sign: (outside docker) droidian-build-tools script signs the packages
 # recipes creation: src/build-tools/image.sh found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian
 # debs creation: found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian/apt
    #
    # Set package paths
    droidian_build_tools_fullpath="${START_DIR}/droidian-build-tools/bin"
    adapt_droidian_template_relpath="droidian"
    package_relpath="droidian/${vendor}/${codename}/packages/adaptation-${vendor}-${codename}"
    adapt_droidian_apt_reldir="droidian/${vendor}/${codename}/droidian/apt"
    ## Set paths for docker
    PACKAGE_DIR="${droidian_build_tools_fullpath}/${package_relpath}"
    RESULT_DIR="$(mktemp)"
    LOCAL_REPO_DIR="${droidian_build_tools_fullpath}/${adapt_droidian_apt_reldir}"
    ## Set dirs to mount on the docker container
    buildd_fullpath="${RESULT_DIR}" 
    buildd_sources_fullpath="${PACKAGE_DIR}"
    buildd_local_repo_fullpath="${LOCAL_REPO_DIR}"

#AQUI

}

fn_docker_config_kernel_source() {
    APT_INSTALL_EXTRA=" \
        bison flex libpcre3 libfdt1 libssl-dev libyaml-0-2 \
        linux-initramfs-halium-generic linux-initramfs-halium-generic:arm64 \
        linux-android-${DEVICE_VENDOR}-${DEVICE_MODEL}-build-deps \
        mkbootimg mkdtboimg avbtool bc android-sdk-ufdt-tests cpio device-tree-compiler kmod libkmod2 \
        gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android \
        libgcc-4.9-dev-aarch64-linux-android-cross \
        binutils-gcc4.9-aarch64-linux-android binutils-aarch64-linux-gnu"
       #clang-android-6.0-4691093 clang-android-10.0-r370808 \
    # Set SOURCES_FULLPATH to parent kernel dir
    SOURCES_FULLPATH="$(dirname ${START_DIR})"
    ## get kernel info
    export KERNEL_DIR="${START_DIR}"
    # Set KERNEL_NAME to current dir name
    pkg_dirname=$(basename ${START_DIR})
    package_name=${pkg_dirname}
    KERNEL_NAME="${package_name}"
    #kernel_device=$(echo ${KERNEL_NAME} | awk -F'-' '{print $(NF-1)"-"$NF}')
    export PACKAGES_DIR="$SOURCES_FULLPATH/out-$KERNEL_NAME"
    ## Set dirs to mount on the docker container
    buildd_fullpath="${$PACKAGES_DIR}" 
    buildd_sources_fullpath="${KERNEL_DIR}"
    ## Set kernel build output paths
    KERNEL_BUILD_OUT_KOBJ_PATH="$KERNEL_DIR/out/KERNEL_OBJ"
    KERNEL_BUILD_OUT_DEBS_PATH="$PACKAGES_DIR/debs"
    KERNEL_BUILD_OUT_DEBIAN_PATH="$PACKAGES_DIR/debian"
    KERNEL_BUILD_OUT_LOGS_PATH="$PACKAGES_DIR/logs"
    KERNEL_BUILD_OUT_OTHER_PATH="$PACKAGES_DIR/other"
    ## Create kernel build output dirs
    # [ -d "${KERNEL_BUILD_OUT_KOBJ_PATH}" ] || mkdir -v -p ${KERNEL_BUILD_OUT_KOBJ_PATH}
    [ -d "$PACKAGES_DIR" ] || mkdir -v $PACKAGES_DIR
    [ -d "$KERNEL_BUILD_OUT_DEBS_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_DEBS_PATH
    [ -d "$KERNEL_BUILD_OUT_DEBIAN_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_DEBIAN_PATH
    [ -d "$KERNEL_BUILD_OUT_LOGS_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_LOGS_PATH
    [ -d "$KERNEL_BUILD_OUT_OTHER_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_OTHER_PATH
    ## Backups info
    BACKUP_FILE_NOM="Backup-kernel-build-outputs-$KERNEL_NAME.tar.gz"
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

fn_patch_kernel_snippet_cross_32() {
# Requires "CROSS_COMPILE_32 = arm-linux-gnueabi-" on kernel-info.mk
    ## Patch kenel-snippet.mk to fix vdso32 compilation for selected devices
    ## CURRENTLY not used since the Droidian packaging configures the 32 bit compiler
    if [ "$DEVICE_MODEL" == "vayu" ]; then
	echo; echo "Patching kernel-snippet.mk to avoid vdso32 build error on some devices"
	replace_pattern='s/CROSS_COMPILE_ARM32=$(CROSS_COMPILE)/CROSS_COMPILE_ARM32=$(CROSS_COMPILE_32)/g'
	CMD="sed -i ${replace_pattern} /usr/share/linux-packaging-snippets/kernel-snippet.mk"
	fn_cmd_on_container
    fi
}
fn_patch_kernel_snippet_python275b_path() {
    ## Patch kenel-snippet.mk to add te python275b path to the FULL_PATH var
    if [ "$DEVICE_MODEL" == "vayu" ]; then
	echo; echo "Patching kernel-snippet.mk to add te python275b path to the FULL_PATH var"
	# WORKS replace_pattern='s|debian/path-override:|debian/path-override:/buildd/sources/droidian/python/2.7.5/bin:|g'
	replace_pattern='s|$(BUILD_PATH):$(CURDIR)/debian/path-override:|$(BUILD_PATH):$(CURDIR)/debian/path-override:/buildd/sources/droidian/python/2.7.5/bin:|g'
	#replace_pattern="s|FULL_PATH = \$\(BUILD_PATH\)\:\$\(CURDIR\)\/debian\/path-override\:\$\{PATH\}|FULL_PATH = \$\(BUILD_PATH\)\:\$\(CURDIR\)\/debian\/path-override\:\/buildd\/sources\/droidian\/python\/2\.7\.5\/bin\:\$\{PATH\}|g"
	CMD="sed -i "${replace_pattern}" /usr/share/linux-packaging-snippets/kernel-snippet.mk"
	fn_cmd_on_container
    fi
}


fn_kernel_config_droidian() {
    ## Check and install required packages
    arr_pack_reqs=( "linux-packaging-snippets" )

    # Temporary disabled 2024-05-17 ## fn_install_apt "${arr_pack_reqs[@]}"

    arr_kernel_version=()
    arr_kernel_version_str=( '^VERSION' '^PATCHLEVEL' '^SUBLEVEL' )
    for version_str in ${arr_kernel_version_str[@]}; do
	arr_kernel_version+=( $(cat ${KERNEL_DIR}/Makefile | grep ${version_str} | head -n 1 | awk '{print $3}') )
    done
    KERNEL_BASE_VERSION="${arr_kernel_version[0]}.${arr_kernel_version[1]}-${arr_kernel_version[2]}"
    KERNEL_BASE_VERSION_SHORT="${arr_kernel_version[0]}.${arr_kernel_version[1]}"

    ## Config debian packaging
    KERNEL_INFO_MK_FILENAME="kernel-info.mk"
    KERNEL_INFO_MK_FULLPATH_FILE="${KERNEL_DIR}/debian/kernel-info.mk"
    ## Create packaging dirs if not exist
    arr_pack_dirs=( "debian" "debian/source" "debian/initramfs-overlay/scripts" "droidian/scripts" "droidian/common_fragments" )

    ## Create droidian and debian packaging dirs
    for pack_dir in ${arr_pack_dirs[@]}; do
	[ -d "${pack_dir}" ] || mkdir -p -v "${pack_dir}"
    done

    ## Create kernel-info.mk from template
    if [ ! -f "${KERNEL_INFO_MK_FULLPATH_FILE}" ]; then
    	src_fullpath_file="/usr/share/linux-packaging-snippets/kernel-info.mk.example"
    	dst_fullpath_file="/buildd/sources/debian/${KERNEL_INFO_MK_FILENAME}"
    	CMD="cp ${src_fullpath_file} ${dst_fullpath_file}"
    	fn_cmd_on_container
        ## Check if the kernel snippet was created
        [ ! -f "${KERNEL_INFO_MK_FULLPATH_FILE}" ] && abort "Error creating ${KERNEL_INFO_MK_FULLPATH_FILE}!"

	## Configuring the kernel version on kernel-info.mk
	echo; echo "Configuring the kernel version on kernel-info.mk..."
	#replace_pattern="s/KERNEL_BASE_VERSION = .*/KERNEL_BASE_VERSION = ${KERNEL_BASE_VERSION}/g"
	replace_pattern="s/KERNEL_BASE_VERSION = .*/KERNEL_BASE_VERSION = ${KERNEL_BASE_VERSION}/g"
	sed -i "s/KERNEL_BASE_VERSION.*/KERNEL_BASE_VERSION\ =\ ${KERNEL_BASE_VERSION}/g" \
		${KERNEL_INFO_MK_FULLPATH_FILE}

	## Miniml kernel-info.mk config
	echo; read -p "Enter a device vendor name: " answer
	sed -i "s/DEVICE_VENDOR.*/DEVICE_VENDOR\ =\ ${answer}/g" ${KERNEL_INFO_MK_FULLPATH_FILE}
	echo; read -p "Enter a device model name: " answer
	sed -i "s/DEVICE_MODEL.*/DEVICE_MODEL\ =\ ${answer}/g" ${KERNEL_INFO_MK_FULLPATH_FILE}
	echo; read -p "Enter the full device name: " answer
	sed -i "s/DEVICE_FULL_NAME.*/DEVICE_FULL_NAME\ =\ ${answer}/g" ${KERNEL_INFO_MK_FULLPATH_FILE}
	echo; read -p "Enter the cmdline: " answer
	sed -i "s/KERNEL_BOOTIMAGE_CMDLINE.*/KERNEL_BOOTIMAGE_CMDLINE\ =\ ${answer}/g" ${KERNEL_INFO_MK_FULLPATH_FILE}
	echo; read -p "Enter the defconf file name: " answer
	sed -i "s/KERNEL_DEFCONFIG.*/KERNEL_DEFCONFIG\ =\ ${answer}/g" ${KERNEL_INFO_MK_FULLPATH_FILE}
    fi

    ## Check if one of the mínimal vars is unconfigured
    ## TODO: Implement a for to check all the mínimal vars
    kernel_info_mk_is_configured=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_MODEL = device1')
    [ -n "${kernel_info_mk_is_configured}" ] && abort "kernel-info.mk is unconfigured!"

    ## Set Kernel Info constants
    DEVICE_DEFCONFIG_FILE=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'KERNEL_DEFCONFIG' | awk -F' = ' '{print $2}')
    DEVICE_VENDOR=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_VENDOR' | awk -F' = ' '{print $2}')
    DEVICE_MODEL=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_MODEL' | awk -F' = ' '{print $2}')
    DEVICE_ARCH=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'KERNEL_ARCH' | awk -F' = ' '{print $2}')
    DEVICE_FULL_NAME=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_FULL_NAME' | awk -F' = ' '{print $2}')

    ## Create compat file
    if [ ! -f "${KERNEL_DIR}/debian/compat" ]; then
        echo "13" > ${KERNEL_DIR}/debian/compat
    fi
    ## Create format file
    if [ ! -f "${KERNEL_DIR}/debian/source/format" ]; then
        echo "3.0 (native)" > ${KERNEL_DIR}/debian/source/format
    fi
    ## Create rules file
    if [ ! -f "${KERNEL_DIR}/debian/rules" ]; then
	url=https://raw.githubusercontent.com/droidian-devices/linux-android-fxtec-pro1x/droidian/debian/rules
        wget -O ${KERNEL_DIR}/debian/rules ${url}
    fi
    ## Create halium-hooks file
    if [ ! -f "${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks" ]; then
        url=https://raw.githubusercontent.com/droidian-devices/linux-android-fxtec-pro1x/droidian/debian/initramfs-overlay/scripts/halium-hooks 
        wget -O ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks "${url}"
	sed -i "s/# Initramfs hooks for .*/# Initramfs hooks for ${DEVICE_FULL_NAME}/g" ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        chmod +x ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
    fi

    ## Add defconf fragments
    DEFCONF_FRAGS_DIR="droidian"
    DEFCONF_COMM_FRAGS_DIR="${DEFCONF_FRAGS_DIR}/common_fragments"
    ## Get Droidian defconfig common_fragments
    echo; echo "Checking for defconfig common fragments..."
    DEFCONF_COMM_FRAGS_URL="https://raw.githubusercontent.com/droidian-devices/common_fragments/${KERNEL_BASE_VERSION_SHORT}-android"
    arr_frag_files=( "debug.config" "droidian.config" "halium.config" )
    for frag_file in ${arr_frag_files[@]}; do
	## Get the file if not exist
	[ -f "${KERNEL_DIR}/${DEFCONF_COMM_FRAGS_DIR}/${frag_file}" ] \
	   || wget -O "${KERNEL_DIR}/${DEFCONF_COMM_FRAGS_DIR}/${frag_file}" \
	   "${DEFCONF_COMM_FRAGS_URL}/${frag_file}" 2>&1  >/dev/null
   done

    ## Get Droidian defconfig prox1_fragment file and save as sample
    DEFCONF_DEV_FRAG_URL="https://raw.githubusercontent.com/droidian-devices/linux-android-fxtec-pro1x/droidian/droidian/pro1x.config"
    echo; echo "Checking for device defconfig fragment sample file..."
    ## Get the file if not exist
    [ ! -f "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}-sample.config" ] \
        &&  wget -O "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}-sample.config" "${DEFCONF_DEV_FRAG_URL}"
    ## Create the device fragment file if not exist
    [ ! -f "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}.config" ] \
	&& cp -v "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}-sample.config" \
	"${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}.config"

    ## Sow vars defined
    fn_print_vars
}

fn_build_package_on_container() {
    ## TODO Recreate the systemd wants links on the sparse directory
    #[ ! -f "create-services-links.sh" ] && abort "create-services-links.sh not found!"
    #./create-services-links.sh

    # Script creation to launch compilation inside the container.
    build_script_name="compile-package.with-droidian-releng.sh"
    echo '#!/bin/bash' > ${SOURCES_FULLPATH}/${build_script_name}
    echo >> ${SOURCES_FULLPATH}/${build_script_name}
    echo 'chmod +x /buildd/sources/debian/rules' >> ${SOURCES_FULLPATH}/${build_script_name}
    echo 'cd /buildd/sources' >> ${SOURCES_FULLPATH}/${build_script_name}
    #
    #echo "## Restore releng-tools scripts" >> ${SOURCES_FULLPATH}/${build_script_name}
    #echo >> ${SOURCES_FULLPATH}/${build_script_name}
    #echo "apt-get --reinstall install releng-tools -y" >> ${SOURCES_FULLPATH}/${build_script_name}
    #echo "## Add more tag prefixes" >> ${SOURCES_FULLPATH}/${build_script_name}
    #echo "sed -i 's|tag_prefixes=(\"droidian/.*),|tag_prefixes=(\"droidian/\",\"stable/\",\"release/\",),|g'" \
    #
    ## Get the package version from the script whose name is the packqge name
    echo >> ${SOURCES_FULLPATH}/${build_script_name}
    echo "package_version=\"\$(cat ${package_name}.sh | grep \"^TOOL_VERSION\" | awk -F'=' '{print \$2}' | sed 's/\"//g')\"" >> ${SOURCES_FULLPATH}/${build_script_name}
    #
    ## Patch releng-build-changelog to set the package version externally
    echo >> ${SOURCES_FULLPATH}/${build_script_name}
    echo 'comes=\"' >> ${SOURCES_FULLPATH}/${build_script_name}
    echo "sed -i \"s|starting_version = strategy()|starting_version = \"\$comes\${package_version}\$comes\" #RESTORE|g\" /usr/lib/releng-tools/build_changelog.py" >> ${SOURCES_FULLPATH}/${build_script_name}
    #
    ## Call releng to build package
    echo >> ${SOURCES_FULLPATH}/${build_script_name}
    echo "## Call releng" >> ${SOURCES_FULLPATH}/${build_script_name}
    echo "RELENG_FULL_BUILD=yes RELENG_HOST_ARCH=${host_arch} releng-build-package" \
	    >> ${SOURCES_FULLPATH}/${build_script_name}
    #RELENG_TAG_PREFIX=stable/  RELENG_BRANCH_PREFIX
    #
    ## Restore the externally forced version on releng-buils-changelog
    echo >> ${SOURCES_FULLPATH}/${build_script_name}
    echo "sed -i \"s|starting_version = .*RESTORE|starting_version = strategy()|g\" /usr/lib/releng-tools/build_changelog.py" >> ${SOURCES_FULLPATH}/${build_script_name}
    #
    ## Add x perms to the compiler script
    chmod u+x ${SOURCES_FULLPATH}/${build_script_name}
    #
    ## Build package on container
    docker exec -it $CONTAINER_NAME bash /buildd/sources/${build_script_name}
    #missatge "Docker command is disabled for testing!"

    info "Build package finished."


<< "ADAPTATION_IN_DEVELOPMENT"
AQUI


## Global config
bkp_private_filename="backup-droidian-private-gpg-apt-${vendor}-${codename}.tar.gz"
bkp_template_filename="backup-droidian-adaptation-fresh-template-${vendor}-${codename}.tar.gz"
bkp_adapt_git_repo_filename="backup-droidian-adaptation-git-repo-${vendor}-${codename}.tar.gz"
build_tools_droidian_fullpath="${START_DIR}/droidian-build-tools/bin"
build_tools_src_fullpath="${START_DIR}/droidian-build-tools/bin/src/build-tools"
build_private_fullpath="${START_DIR}/droidian-build-tools/bin/droidian/${vendor}/${codename}/private"
build_adaptation_fullpath="${START_DIR}/droidian-build-tools/bin/droidian/${vendor}/${codename}/packages/adaptation-${vendor}-${codename}"

## Extract the full droidian-build-package with the template
[ ! -f "${bkp_template_filename}" ] && abort "Build template ${bkp_template_filename} not found!"
[ ! -d "${START_DIR}/droidian-build-tools" ] && cd ${START_DIR} && tar zxf "${bkp_template_filename}"
## Update the suite to trixie on droidian-build-tools
#sed -i 's/bookworm/trixie/g' ${build_tools_src_fullpath}/common.sh

## create link to the adaptation git repo on the droidian-build-tools structure
[ -d "${build_adaptation_fullpath}" ] && mv ${build_adaptation_fullpath} ${build_adaptation_fullpath}_bkp \
    && ln -s "${START_DIR}" "${build_adaptation_fullpath}"
[ -L "${build_adaptation_fullpath}" ] && rm "${build_adaptation_fullpath}" \
    && ln -s "${START_DIR}" "${build_adaptation_fullpath}"

## Build the adaptation packages
## by default arm64 host arch is defined. To use adm64 add "-b amd64" flag
cd ${build_adaptation_fullpath} && ${build_tools_droidian_fullpath}/droidian-build-package -b amd64
cd ${START_DIR}
ADAPTATION_IN_DEVELOPMENT

}

fn_build_kernel_on_container() {
    ## Call droidian kernel configuration function
    fn_kernel_config_droidian

    # Script creation to launch compilation inside the container.
    build_script_name="compile-droidian-kernel.sh"
    echo '#!/bin/bash' > $KERNEL_DIR/${build_script_name}
    echo >> $KERNEL_DIR/${build_script_name}
    #echo "export PATH=/bin:/sbin:$PATH" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export R=llvm-ar" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export NM=llvm-nm" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export OBJCOPY=llvm-objcopy" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export OBJDUMP=llvm-objdump" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export STRIP=llvm-strip" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export CC=clang" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export CROSS_COMPILE=aarch64-linux-gnu-" >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'chmod +x /buildd/sources/debian/rules' >> $KERNEL_DIR/${build_script_name}
    echo 'cd /buildd/sources' >> $KERNEL_DIR/${build_script_name}
    echo 'rm -f debian/control' >> $KERNEL_DIR/${build_script_name}
    echo 'debian/rules debian/control' >> $KERNEL_DIR/${build_script_name}
    #echo 'source /buildd/sources/droidian/scripts/python-zlib-upgrade.sh' >> $KERNEL_DIR/compile-droidian-kernel.sh
    #fn_patch_kernel_snippet_python275b_path
    #fn_patch_kernel_snippet_cross_32 # Requires "CROSS_COMPILE_32 = arm-linux-gnueabi-" on kernel-info.mk
    #echo >> $KERNEL_DIR/compile-droidian-kernel.sh

    #echo "export PATH=\"/buildd/sources/droidian/python/2.7.5/bin:$PATH\"" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export LD_LIBRARY_PATH=\"/buildd/sources/droidian/python/2.7.5/bin\"" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export PYTHONHOME=\"/buildd/sources/droidian/python/2.7.5\"" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export PYTHONPATH=\"/buildd/sources/droidian/python/2.7.5/lib/python2.7\"" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "RELENG_HOST_ARCH=\"arm64\" /buildd/sources/releng-build-package-berb-edited" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #wget -O $KERNEL_DIR/releng-build-package-berb-edited \
	#    https://raw.githubusercontent.com/droidian-berb/berb-droidian-kernel-build-docker-mgr/release/1.0.0-3/releng-build-package-berb-edited
    #${SUDO} chmod u+x $KERNEL_DIR/releng-build-package-berb-edited

    ## Releng command
    echo >> $KERNEL_DIR/${build_script_name}
    echo "RELENG_HOST_ARCH=${host_arch} releng-build-package" >> $KERNEL_DIR/${build_script_name}
    ${SUDO} chmod u+x $KERNEL_DIR/${build_script_name}

    # ask for disable install build deps in debian/kernel.mk if enabled.
    #INSTALL_DEPS_IS_ENABLED=$(grep -c "^DEB_TOOLCHAIN")
    #if [ "$INSTALL_DEPS_IS_ENABLED" -eq "1" ]; then
    #	echo "" && read -p "Want you disable install build deps? Say \"n\" if not sure! y/n:  " OPTION
    #	case $OPTION in
    #		y)
    #			fn_disable_install_deps_on_build
    #			;;
    #	esac
    #fi
    docker exec -it $CONTAINER_NAME bash /buildd/sources/compile-droidian-kernel.sh
    echo; echo "Compilation finished."

    # fn_create_outputs_backup
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
    echo && echo "Action is required:"
    echo && echo " 1 - Create container"
    echo " 2 - Remove container"
    echo; echo " 3 - Start container"
    echo " 4 - Stop container"
    echo; echo " 5 - Commit container"
    echo "     Commits current container state."
    echo "     Then creates new container from the commit."
    echo "     If a image with tag latest is found, it will be used by default"
    echo; echo " 6 - Install extra packages from apt."
    echo "     Not fully working!"
    echo; echo " 7 - Shell to container"
    #	echo " 8 - Command to container" # only internal use
    #	echo echo " 9 - Setup build env. OPTIONAL Implies option 3."
    echo; echo "10 - Build kernel on container"
    echo; echo "11 - Configure a Droidian kernel (android kernel)"
    echo; echo "12 - Build package on container"
    echo; echo "20 - Backup kernel build output relevant files"
    echo; read -p "Select an option: " OPTION
    case $OPTION in
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
	6)
	    ACTION="install-apt-extra"
	    ;;
	7)
	    ACTION="shell-to"
	    ;;
#	8)
#	    ACTION="command-to"
#	    ;;
#	9)
#	    ACTION="setup-build-env"
#	    ;;
	10)
	    ACTION="build-kernel-on-container"
	    ;;
	11)
	    ACTION="config-droidian-kernel"
	    ;;
	12)
	    ACTION="build-package-on-container"
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
fn_build_env_base_paths_config
fn_docker_global_config
fn_action_prompt
#fn_set_container_commit_if_exists

#fn_print_vars
echo

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
#elif [ "$ACTION" == "command-to" ]; then
#   fn_cmd_on_container
#elif [ "$ACTION" == "setup-build-env" ]; then
#   fn_build_env_base_paths_config
elif [ "$ACTION" == "config-droidian-kernel" ]; then
    fn_kernel_config_droidian
elif [ "$ACTION" == "install-apt-extra" ]; then
    fn_install_apt_extra
elif [ "$ACTION" == "commit-container" ]; then
    fn_commit_container
elif [ "$ACTION" == "build-kernel-on-container" ]; then
    fn_build_kernel_on_container
elif [ "$ACTION" == "build-package-on-container" ]; then
    fn_build_package_on_container
elif [ "$ACTION" == "create-outputs-backup" ]; then
    fn_create_outputs_backup
else
    echo "SCRIPT END: Action not implemented."
fi

