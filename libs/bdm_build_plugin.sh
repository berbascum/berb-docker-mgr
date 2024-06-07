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

fn_dir_is_git() {
    ## Abort if no .git directory found
    [ ! -d ".git" ] && ABORT "The current dir should be a git repo!"
}

fn_debian_control_found() {
    ## Abort if no debian/control file found
    [ ! -f "debian/control" ] && ABORT "debian control file not found!"
}

fn_pkg_source_type_detection() {
    ## Save start fullpath
    START_DIR=$(pwd)
    ## check for git dir
    fn_dir_is_git # Abort if not
    ## Check for debian control
    fn_debian_control_found # Abort if not
    ## Get the package name from debian control
    package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')

    # Cerca un arxiu README de linux kernel
    if [ -e "$START_DIR/README" ]; then
	## Check if is kernel
        IS_KERNEL=$(cat $START_DIR/README | head -n 1 | grep -c "Linux kernel")
        [ "${IS_KERNEL}" -eq '0' ] \
	    && ABORT "No Linux kernel README file found in current dir."
        APT_INSTALL_EXTRA="releng-tools"
	INFO "Kernel source dir detected!"
	docker_mode="kernel"
	## Load berb-build-droidian-kernel.sh
	source  /usr/lib/${TOOL_NAME}/berb-build-droidian-kernel.sh
	## Call kernel source config function
	fn_docker_config_kernel_source
    elif [ -e "${START_DIR}/sparse" ]; then
	## Set docker mode
	docker_mode="package"
	## Get the package type
	pkg_type=""
	if [ -z "${pkg_type}" ]; then
	   if [ -f "debian/adaptation-${vendor}-${codename}-configs.install" ]; then
	       pkg_type="droidian_adapt"
               APT_INSTALL_EXTRA="releng-tools"
	       INFO "Package type detected: \"${pkg_type}\""
           else
	       pkg_type="standard_pkg"
               APT_INSTALL_EXTRA="releng-tools"
	       INFO "Package type detected: \"${pkg_type}\""
	       ## Source the corresponding pkg_type lib
	       source /usr/lib/${TOOL_NAME}/berb-build-droidian-package.sh
	   fi
	   ## Source the build droidian package lib
	   source /usr/lib/${TOOL_NAME}/berb-build-droidian-package.sh
           ## Configure the droidian package source
           fn_docker_config_droidian_package_source
        fi
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
