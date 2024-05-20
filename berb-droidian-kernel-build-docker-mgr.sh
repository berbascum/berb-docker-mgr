#!/bin/bash


TOOL_NAME='berb-droidian-kernel-build-docker-mgr'
TOOL_VERSION='1.0.0.3'
TOOL_BRANCh="release/${TOOL_VERSION}"

# Not used yet by this script:
# VERSIO_SCRIPTS_SHARED_FUNCS="0.2.1"

# Upstream-Name: berb-droidian-kernel-build-docker-mgr
# Source: https://gitlab.com/droidian-berb/berb-droidian-kernel-build-docker-mgr
  ## Script that manages a custom docker container with Droidian build environment

# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
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
    # New: Basic check to determine if start dir a kernel source root dir.
    # New: fn_create_outputs_backup: After compilation, script archives most output relevant files and archive them to tar.gz
    # New: fn_remove_container
    # Conf: Add net-tools to apt depends
    # Fix: docker image name for new container creation.
    # 

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
    

####################
## Configurations ##
####################
fn_configura_sudo() {
	if [ "$USER" != "root" ]; then SUDO='sudo'; fi
}

abort() {
	echo; echo "$*"
	exit 1
}

missatge() {
    echo; echo "$*"
}

missatge_return() {
    echo; echo "$*"
    return 0
}

fn_verificacions_path() {
    START_DIR=$(pwd)
    # Cerca un aerxiu README de linux kernel
    [ ! -e "$START_DIR/README" ] && abort "README file not found. Please exec th script from the git kernel dir"
    IS_KERNEL=$(cat $START_DIR/README | head -n 1 | grep -c "Linux kernel")
    [ "${IS_KERNEL}" -eq '0' ] && abort "No Linux kernel README file found in current dir."
}

fn_build_env_base_paths_config() {
	# Set SOURCES_PATH to parent kernel dir
	SOURCES_PATH="$(dirname ${START_DIR})"
	## get kernel info
	export KERNEL_DIR="${START_DIR}"
	# Set KERNEL_NAME to current dir name
	KERNEL_NAME=$(basename ${START_DIR})
	export PACKAGES_DIR="$SOURCES_PATH/out-$KERNEL_NAME"

	## Set kernel build output paths
	KERNEL_BUILD_OUT_KOBJ_PATH="$KERNEL_DIR/out/KERNEL_OBJ"
	KERNEL_BUILD_OUT_DEBS_PATH="$PACKAGES_DIR/debs"
	KERNEL_BUILD_OUT_DEBIAN_PATH="$PACKAGES_DIR/debian"
	KERNEL_BUILD_OUT_LOGS_PATH="$PACKAGES_DIR/logs"
	KERNEL_BUILD_OUT_OTHER_PATH="$PACKAGES_DIR/other"
	## Create kernel build output dirs
  	# [ -d "${KERNEL_BUILD_OUT_KOBJ_PATH}" ] || mkdir -v -p ${KERNEL_BUILD_OUT_KOBJ_PATH}
  	[ -d "$PACKAGES_DIR" ] || -v mkdir $PACKAGES_DIR
  	[ -d "$KERNEL_BUILD_OUT_DEBS_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_DEBS_PATH
  	[ -d "$KERNEL_BUILD_OUT_DEBIAN_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_DEBIAN_PATH
  	[ -d "$KERNEL_BUILD_OUT_LOGS_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_LOGS_PATH
  	[ -d "$KERNEL_BUILD_OUT_OTHER_PATH" ] || mkdir -v $KERNEL_BUILD_OUT_OTHER_PATH

	## Backups info
	BACKUP_FILE_NOM="Backup-kernel-build-outputs-$KERNEL_NAME.tar.gz"
}

fn_docker_global_config() {
    ## Docker constants
    DEFAULT_CONTAINER_NAME='droidian-build-env'
    CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
    CONTAINER_COMMITED_NAME='droidian-build-env-custom'
    IMAGE_BASE_NAME='quay.io/droidian/build-essential:trixie-amd64'
    IMAGE_BASE_TAG='bookworm-amd64'
    IMAGE_COMMIT_NAME='custom/build-essential'
    IMAGE_COMMIT_TAG='bookworm-amd64'
}



fn_install_apt_extra() {
    APT_INSTALL_EXTRA="net-tools vim locate git device-tree-compiler, linux-initramfs-halium-generic:arm64, binutils-aarch64-linux-gnu, clang-android-10.0-r370808, gcc-4.9-aarch64-linux-android, g++-4.9-aarch64-linux-android, libgcc-4.9-dev-aarch64-linux-android-cross linux-android-${DEVICE_VENDOR}-${DEVICE_MODEL}-build-deps"
   # bison flex libpcre3 libfdt1 libssl-dev libyaml-0-2"
    #linux-initramfs-halium-generic linux-initramfs-halium-generic:arm64
    #mkbootimg mkdtboimg avbtool bc android-sdk-ufdt-tests cpio device-tree-compiler kmod libkmod2"
    #clang-android-6.0-4691093 clang-android-10.0-r370808
    #gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android
    #libgcc-4.9-dev-aarch64-linux-android-cross
    #binutils-gcc4.9-aarch64-linux-android binutils-aarch64-linux-gnu
    #python2.7 python2.7-minimal libpython2.7-minimal libpython2.7-stdlib \

    fn_install_apt "${APT_INSTALL_EXTRA}"
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
fn_action_prompt() {
## Function to get a action
	echo && echo "Action is required:"
	echo && echo " 1 - Create container"
	echo " 2 - Remove container"
	echo && echo " 3 - Start container"
	echo " 4 - Stop container"
	echo && echo " 5 - Commit container"
        echo "     Commits current container state."
        echo "     Then creates new container from the commit."
        echo "     Script permanent sets new container as default."
	echo "     ## Actually only support 1 existing commit at same time!"
	#echo && echo " 6 - Install extra packages from apt."
	echo && echo " 7 - Shell to container"
#	echo " 8 - Command to container" # only internal use
#	echo echo " 9 - Setup build env. OPTIONAL Implies option 3."
	echo && echo "10 - Build kernel on container"
	echo && echo "11 - Configure a Droidian kernel (android kernel)"
	echo && echo "12 - Backup kernel build output relevant files"
	echo && read -p "Select an option: " OPTION
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
#		5)
#			ACTION="install-apt-extra"
#			;;
		7)
			ACTION="shell-to"
			;;
#		8)
#			ACTION="command-to"
#			;;
#		9)
#			ACTION="setup-build-env"
#			;;
		10)
			ACTION="build-kernel-on-container"
			;;
		11)
			ACTION="config-droidian-kernel"
			;;
		12)
			ACTION="create-outputs-backup"
			;;
		*)
			echo "" && echo "Option not implemented!" && exit 1
			;;
	esac
}



fn_setup_build_env() {
	echo && echo "To do."
}

######################
## Docker functions ##
######################
fn_create_container() {
# Creates the container
	CONTAINER_EXISTS=$(${SUDO} docker ps -a | grep -c ${CONTAINER_NAME})
	if [ "${CONTAINER_EXISTS}" -eq "0" ]; then
		if [ "$IS_COMMIT"º == "yes" ]; then
			IMAGE_NAME="$IMAGE_COMMIT_NAME:$IMAGE_COMMIT_TAG"
		else
			IMAGE_NAME="$IMAGE_BASE_NAME"
		fi
		echo; echo "Creating docker container \"${CONTAINER_NAME}\" using \"${IMAGE_NAME}\" image..." 
		$SUDO docker -v create --name $CONTAINER_NAME -v $PACKAGES_DIR:/buildd \
			-v $KERNEL_DIR:/buildd/sources -i -t "${IMAGE_NAME}"
		echo && echo "Container created!"
	else
		echo && echo "Container already exists!" && exit 4
	fi
}
fn_remove_container() {
# Removes a the container
	CONTAINER_EXIST=$(${SUDO} docker ps -a | grep -c "$CONTAINER_NAME")
	CONTAINER_ID=$(${SUDO} docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
	if [ "$CONTAINER_EXIST" -eq '0' ]; then
		echo && echo "Container $CONTAINER_NAME not exists..."
		echo
	else
		echo && read -p "SURE to REMOVE container $CONTAINER_NAME [ yes | any-word ] ? " RM_CONT
	fi
	if [ "$RM_CONT" == "yes" ]; then
		echo && echo "Removing container..."
		fn_stop_container
		${SUDO} docker rm $CONTAINER_ID
	else
		echo && echo "Container $CONTAINER_NAME will NOT be removed as user choice"
		echo
	fi
}
fn_set_container_commit_if_exists() {
	COMMIT_EXISTS=$(${SUDO} docker images -a | grep -c "$IMAGE_COMMIT_NAME")
	if [ "$COMMIT_EXISTS" -eq "1" ]; then
		echo "" && echo "Setting detected commit as default container..."
		CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
		IS_COMMIT='yes'
	fi
}
fn_start_container() {
	IS_STARTED=$(${SUDO} docker ps -a | grep $CONTAINER_NAME | awk '{print $5}' | grep -c 'Up')
	if [ "$IS_STARTED" -eq "0" ]; then
		$SUDO docker start $CONTAINER_NAME
	fi
}
fn_stop_container() {
	${SUDO} docker stop $CONTAINER_NAME
}
fn_get_default_container_id() {
	# Search for original container id
	DEFAULT_CONT_ID=$(${SUDO} docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
}
fn_commit_container() {
	if [ "$CONTAINER_NAME" == "droidian-build-env-custom" ]; then
		echo && echo "Creation of more than 1 commit is not supported."
		echo "You can change the consts IMAGE_COMMIT_NAME and CONTAINER_COMMITED_NAME values with a new name."
		echo "After run script again a new commit will be created."
		echo
		exit 3
	fi
	fn_get_default_container_id
	# Commit creation
	echo && echo "Creating commit \"$IMAGE_COMMIT_NAME\"..."
	echo "Please be patient!!!"
	${SUDO} docker commit $DEFAULT_CONT_ID $IMAGE_COMMIT_NAME
	echo && echo "Stoping original container..."
	${SUDO} docker stop $DEFAULT_CONTAINER_NAME
	# Set container commit name as current container
	CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
	# Create new container from commit image.
	echo && echo "Creating new container from te commit..."
	fn_create_container
	echo && echo Creation of the new commit and container with the current state is finished!
	echo
}
fn_shell_to_container() {
    ${SUDO} docker exec -it $CONTAINER_NAME bash
}
fn_cmd_on_container() {
    ${SUDO} docker exec -it ${CONTAINER_NAME} ${CMD}
}
fn_cp_to_container() {
    ${SUDO} docker cp ${copy_src} ${CONTAINER_NAME}:${copy_dst}
}
fn_cp_from_container() {
    ${SUDO} docker cp ${CONTAINER_NAME}:${copy_src} ${copy_dst}
}

############################
## Kernel build functions ##
############################
fn_kernel_config_droidian() {
    ## Check and install required packages
    arr_pack_reqs=( "linux-packaging-snippets" )

    # Temporary disabled 2024-05-17 ## 
    fn_install_apt "${arr_pack_reqs[@]}"

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
    arr_pack_dirs=( "debian" "debian/source" "initramfs-overlay/scripts" "droidian/scripts" "droidian/common_fragments" )
    #arr_dir_exist=()
    for pack_dir in ${arr_pack_dirs[@]}; do
	#[ -d "${pack_dir}" ] && arr_dir_exist+=( "${pack_dir}" ) || mkdir -p -v "${pack_dir}"
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
    kernel_info_mk_is_configured=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_MODEL = device1')
    [ -n "${kernel_info_mk_is_configured}" ] && abort "kernel-info.mk is unconfigured!"

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
        wget ${KERNEL_DIR}/debian/rules \
	   https://raw.githubusercontent.com/droidian-devices/linux-android-fxtec-pro1x/droidian/debian/rules
    fi
    ## Create halium-hooks file
    if [ ! -f "${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks" ]; then
        echo "# Initramfs hooks for Xiaomi Pocophone X3 Pro" \
	    > ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "halium_hook_setup_touchscreen() {" \
	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "        echo 1 > /sys/class/leds/:kbd_backlight/brightness" \
 	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "}" \
	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "" \
 	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "halium_hook_teardown_touchscreen() {" \
	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "        echo 0 > /sys/class/leds/:kbd_backlight/brightness" \
	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        echo "}" \
	>> ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
        chmod +x ${KERNEL_DIR}/debian/initramfs-overlay/scripts/halium-hooks
    fi

    ## Set Kernel Info constants
    DEVICE_DEFCONFIG_FILE=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'KERNEL_DEFCONFIG' | awk -F' = ' '{print $2}')
    DEVICE_VENDOR=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_VENDOR' | awk '{print $3}')
    DEVICE_MODEL=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'DEVICE_MODEL' | awk '{print $3}')
    DEVICE_ARCH=$(cat ${KERNEL_INFO_MK_FULLPATH_FILE} | grep 'KERNEL_ARCH' | awk '{print $3}')

    ## Add defconf fragments
    DEFCONF_FRAGS_DIR="droidian"
    DEFCONF_COMM_FRAGS_DIR="${DEFCONF_FRAGS_DIR}/common_fragments"
    
    echo; echo "Checking for defconfig common fragments..."
    DEFCONF_COMM_FRAGS_URL="https://raw.githubusercontent.com/droidian-devices/common_fragments/${KERNEL_BASE_VERSION_SHORT}-android/"
    arr_frag_files=( "debug.config" "droidian.config" "halium.config" )
    for frag_file in ${arr_frag_files[@]}; do
	## Get the file if not exist
	[ -f "${KERNEL_DIR}/${DEFCONF_COMM_FRAGS_DIR}/${frag_file}" ] \
	   || wget -O "${KERNEL_DIR}/${DEFCONF_COMM_FRAGS_DIR}/${frag_file}" "${DEFCONF_COMM_FRAGS_URL}${frag_file}" 2>&1  >/dev/null
   done

    echo; echo "Checking for device defconfig fragment..."
    DEFCONF_DEV_FRAG_URL="https://raw.githubusercontent.com/droidian-devices/linux-android-fxtec-pro1x/droidian/droidian/pro1x.config"
    ## Get the file if not exist
    [ -f "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}.config" ] \
       || wget -O "${KERNEL_DIR}/${DEFCONF_FRAGS_DIR}/${DEVICE_MODEL}.config" "${DEFCONF_DEV_FRAG_URL}"



    ## Patch kenel-snippet.mk to fix vdso32 compilation for selected devices
    if [ "$DEVICE_MODEL" == "vayu" ]; then
	echo; echo "Patching kernel-snippet.mk to avoid vdso32 build eror on some devices"
	replace_pattern='s/CROSS_COMPILE_ARM32=$(CROSS_COMPILE)/CROSS_COMPILE_ARM32=$(CROSS_COMPILE_32)/g'
	CMD="sed -i ${replace_pattern} /usr/share/linux-packaging-snippets/kernel-snippet.mk"
	# fn_cmd_on_container
    fi

    ## Sow vars defined
    fn_print_vars

    ## Install extra packages
    #fn_install_apt_extra
}

fn_build_kernel_on_container() {
    ## Call droidian kernel configuration function
    fn_kernel_config_droidian

    [ -d "$PACKAGES_DIR" ] || mkdir $PACKAGES_DIR
    # Script creation to launch compilation inside the container.
    echo '#!/bin/bash' > $KERNEL_DIR/compile-droidian-kernel.sh
    echo "export PATH=/bin:/sbin:$PATH" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export R=llvm-ar" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export NM=llvm-nm" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export OBJCOPY=llvm-objcopy" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export OBJDUMP=llvm-objdump" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export STRIP=llvm-strip" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export CC=clang" >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo "export CROSS_COMPILE=aarch64-linux-gnu-" >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'chmod +x /buildd/sources/debian/rules' >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'cd /buildd/sources' >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'rm -f debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'debian/rules debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
    echo 'source /buildd/sources/droidian/scripts/python-zlib-upgrade.sh' >> $KERNEL_DIR/compile-droidian-kernel.sh
    #echo 'exit' >> $KERNEL_DIR/compile-droidian-kernel.sh

    echo 'RELENG_HOST_ARCH="arm64" releng-build-package' >> $KERNEL_DIR/compile-droidian-kernel.sh
    ${SUDO} chmod u+x $KERNEL_DIR/compile-droidian-kernel.sh
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
    ${SUDO} docker exec -it $CONTAINER_NAME bash /buildd/sources/compile-droidian-kernel.sh
    echo  && echo "Compilation finished."

    # fn_create_outputs_backup
}

fn_create_outputs_backup() {
	## Moving output deb files to $PACKAGES_DIR/debs
	echo && echo Moving output deb files to $KERNEL_BUILD_OUT_DEBS_PATH
	mv $PACKAGES_DIR/*.deb $KERNEL_BUILD_OUT_DEBS_PATH

	## Moving output log files to $PACKAGES_DIR/logs
	echo && echo Moving output log files to $KERNEL_BUILD_OUT_LOGS_PATH
	mv $PACKAGES_DIR/*.build* $KERNEL_BUILD_OUT_LOGS_PATH

	## Copyng out/KERNL_OBJ relevant files to $PACKAGES_DIR/other..."
	arr_OUT_DIR_FILES=( \
		'boot.img' 'dtbo.img' 'initramfs.gz' 'recovery*' 'target-dtb' 'vbmeta.img' 'arch/arm64/boot/Image.gz' \
		)
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
		'debian/copyright' 'debian/compat' 'debian/kernel-info.mk' 'debian/rules' 'debian/source' 'debian/initramfs-overlay'  \
		)
	echo && echo "Copying debian dir to $KERNEL_BUILD_OUT_DEBS_PATH..."
	cp -a debian/* $KERNEL_BUILD_OUT_DEBS_PATH/
	for i in ${arr_DEBIAN_FILES[@]}; do
		cp -a $KERNEL_BUILD_OUT_DEBS_PATH/$i debian/
	done
	## Make a tar.gz from PACKAGES_DIR
	echo && echo "Creating $BACKUP_FILE_NOM from $PACKAGES_DIR"
	cd $SOURCES_PATH
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
    echo "DEVICE_MODEL = $DEVICE_MODEL"
    echo "DEVICE_ARCH = $DEVICE_ARCH"
    read -p "Continue..."
} 

############################
## Start script execution ##
############################
## Configuration
fn_ip_forward_activa
fn_configura_sudo
fn_verificacions_path
fn_build_env_base_paths_config
fn_docker_global_config
fn_action_prompt
fn_set_container_commit_if_exists

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
#	fn_cmd_on_container
#elif [ "$ACTION" == "setup-build-env" ]; then
#	fn_build_env_base_paths_config
elif [ "$ACTION" == "config-droidian-kernel" ]; then
	fn_kernel_config_droidian
#elif [ "$ACTION" == "install-apt-extra" ]; then
#	fn_install_apt_extra
elif [ "$ACTION" == "commit-container" ]; then
	fn_commit_container
elif [ "$ACTION" == "build-kernel-on-container" ]; then
	fn_build_kernel_on_container
elif [ "$ACTION" == "create-outputs-backup" ]; then
	fn_create_outputs_backup
else
	echo "SCRIPT END: Action not implemented."
fi

