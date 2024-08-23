#!/bin/bash

## Plugin to automate Droidian kernel compilations using the official Droidian 
## build tools and docker containers managed by the main script.

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

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

############################
## Kernel build functions ##
############################
fn_docker_plugin_container_vars() {
    ## Docker container vars
    fn_bdm_conf_file_load "CONF_USER_DROIDIAN" "docker-container-kernel-vars"
    CONTAINER_BASE_NAME="build-droidian-env-${pkg_dir_name}"
    IMAGE_BASE_NAME='quay.io/droidian/build-essential'
    IMAGE_BASE_TAG="${droidian_host_suite}-${droidian_host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='droidian/build-essential-upg'
    IMAGE_COMMIT_TAG="${droidian_host_suite}-${droidian_host_arch}"
    ## Paths configuration
    # Set SOURCES_FULLPATH to parent kernel dir
    SOURCES_FULLPATH="$(dirname ${START_DIR})"
    ## get kernel info
    export KERNEL_DIR="${START_DIR}"
#    package_name=${pkg_dirname}
    KERNEL_NAME="${pkg_dir_name}"
    #kernel_device=$(echo ${KERNEL_NAME} | awk -F'-' '{print $(NF-1)"-"$NF}')
    export PACKAGES_DIR="$SOURCES_FULLPATH/out-$KERNEL_NAME"
    ## Set dirs to mount on the docker container
    buildd_fullpath="${PACKAGES_DIR}" 
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

fn_docker_plugin_container_conf() {
    debug "fn_docker_plugin_container_conf has no any code yet!"
}

fn_docker_config_kernel_source() {
    ## TODO: Put in the config file
    APT_INSTALL_EXTRA=" \
        bison flex libpcre3 libfdt1 libssl-dev libyaml-0-2 \
        linux-initramfs-halium-generic linux-initramfs-halium-generic:arm64 \
        linux-android-${DEVICE_VENDOR}-${DEVICE_MODEL}-build-deps \
        mkbootimg mkdtboimg avbtool bc android-sdk-ufdt-tests cpio device-tree-compiler kmod libkmod2 \
        gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android \
        libgcc-4.9-dev-aarch64-linux-android-cross \
        binutils-gcc4.9-aarch64-linux-android binutils-aarch64-linux-gnu"
       #clang-android-6.0-4691093 clang-android-10.0-r370808 \
}

fn_kernel_config_droidian() {
    ## Check and install required packages
    arr_pack_reqs=( "linux-packaging-snippets" )

    # Temporary disabled 2024-05-17 ## fn_bdm_apt_upgr_install_pks "${arr_pack_reqs[@]}"

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
    	fn_bdm_docker_cmd_inside_container
        ## Check if the kernel snippet was created
        [ ! -f "${KERNEL_INFO_MK_FULLPATH_FILE}" ] && abort "Error creating ${KERNEL_INFO_MK_FULLPATH_FILE}!"

	## Configuring the kernel version on kernel-info.mk
	echo; echo "Configuring the kernel version on kernel-info.mk..."
	#replace_pattern="s/KERNEL_BASE_VERSION = .*/KERNEL_BASE_VERSION = ${KERNEL_BASE_VERSION}/g"
	replace_pattern="s/KERNEL_BASE_VERSION = .*/KERNEL_BASE_VERSION = ${KERNEL_BASE_VERSION}/g"
	sed -i "s/KERNEL_BASE_VERSION.*/KERNEL_BASE_VERSION\ =\ ${KERNEL_BASE_VERSION}/g" \
		${KERNEL_INFO_MK_FULLPATH_FILE}
	PAUSE "Kernel version configured on kernel-info.mk"

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
	PAUSE "Kernel version configured on kernel-info.mk"

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

fn_build_kernel_on_container() {
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
    echo "RELENG_HOST_ARCH=${releng_host_arch} releng-build-package" >> $KERNEL_DIR/${build_script_name}
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

fn_plugin_sub_exec()  {
    ## Call droidian kernel configuration function
    fn_kernel_config_droidian
    ## Call build-package
    fn_build_kernel_on_container
}
