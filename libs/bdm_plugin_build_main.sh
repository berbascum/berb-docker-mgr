#!/bin/bash

## Plugin to build packages on docker linux containers with package autodetection. 
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

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "Needs to be called with yhe --run flag"

## Include libs
. /usr/lib/berb-bash-libs/bbl_git_lib.sh

fn_update_main_src_file_version_var() {
    ## Update the TOOL_VERSION value on the main source file with the last tag version
    tag_version=$(echo "${last_commit_tag}" | awk -F'/' '{print $2}')
#OBTENIR num versio var TOOL_VERSION
    if [ -n $(cat "${package_name}.sh" | grep "^TOOL_VERSION=\"") ]; then
	tool_vers_var_name="TOOL_VERSION"
    elif [ -n $(cat "${package_name}.sh" | grep "^#TOOL_VERSION=\"") ]; then
        tool_vers_var_name="#TOOL_VERSION"
    else
        tool_vers_var_name=""
    fi
    if [ -n "${tool_vers_var_name}" ]; then
	    tool_vers_var_version=$(cat )
        sed -i "s/^${tool_vers_var_name}=\".*/${tool_vers_var_name}=\"${tag_version}\"/g" "${package_name}.sh"
    fi
        info "Creating tag \"${last_commit_tag}\" on the last commit..."
	git tag "${last_commit_tag}"
}

fn_bblgit_last_two_tags_check() {
    ## Check if the has commit has a tag
    last_commit_tag="$(git tag --contains "HEAD")"
    last_commit_id=$(git log --decorate  --abbrev-commit | head -n 1 | awk '{print $2}')
    prev_last_commit_tag="$(git tag --sort=-creatordate | sed -n '2p')"
    prev_last_commit_id=$(git log --decorate  --abbrev-commit \
        | grep "${prev_last_commit_tag}" | head -n 1 | awk '{print $2}')
	
    if [ -z "${last_commit_tag}" ]; then
        clear && info "The last commit has not assigned a tag and is required"
        last_tag=$(git describe --tags --abbrev=0)
        if [ -n "${last_tag}" ]; then
	    last_commit_tagged=$(git log --decorate  --abbrev-commit \
	       | grep 'tag:' | head -n 1 | awk '{print $2}')
            info "Last commit taged \"${last_commit_tagged}\""
            commit_old_count=$(git rev-list --count HEAD ^"${last_commit_tagged}")
            info "Last tag \"${last_tag}\" and it's \"${commit_old_count}\" commits old"
            ask "Enter a tag name in \"<tag_prefix>/<version>\" format or empty to cancel: "
            [ -z "${answer}" ] && abort "Canceled by user!"
            input_tag_is_valid=$(echo "${answer}" | grep "\/")
            [ -z "${input_tag_is_valid}" ] && error "The typed tag has not a valid format!"
            last_commit_tag="${answer}"
	else
            info "No git tags found!"
            ask "Enter a tag name in \"<tag_prefix>/<version>\" format or empty to cancel: "
            [ -z "${answer}" ] && abort "Canceled by user!"
            input_tag_is_valid=$(echo "${answer}" | grep "\/")
            [ -z "${input_tag_is_valid}" ] && error "The typed tag has not a valid format!"
            last_commit_tag="${answer}"
	fi
    fi
    info "Last commit tag defined: ${last_commit_tag}"
}

fn_get_package_info() {
    ## Get the package version and channel distribution from the last commit tag (mandatory)
    pkg_dist_channel_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $1}')"
    package_version_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $2}')"
    [ -z "${pkg_dist_channel}" ] && pkg_dist_channel="${pkg_dist_channel_tag}"
    [ -z "${package_version}" ] && package_version="${package_version_tag}"
    info "pkg_dist_channel = ${pkg_dist_channel}"
    info "package_version = ${package_version}"
}

fn_pkg_source_type_detection() {
    ## Save start fullpath
    START_DIR=$(pwd)
    ## check for git dir
    fn_bblgit_dir_is_git # Abort if not
    ## Check for debian control
    fn_bblgit_debian_control_found # Abort if not
    ## Get the package name from debian control
    package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')

    # Cerca el dir pkg_rootfs
    if [ -e "${START_DIR}/pkg_rootfs" ]; then
	## Set docker mode
	docker_mode="package"
	pkg_type="debian_package"
        APT_INSTALL_EXTRA=""
	info "Package type detected: \"${pkg_type}\""
	## Source the corresponding pkg_type lib
	. ${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_${pkg_type}.sh --run
    # Cerca el dir sparse
    elif [ -e "${START_DIR}/sparse" ]; then
	## Set docker mode
	docker_mode="package"
	## Get the package type
	if [ -f "debian/adaptation-${vendor}-${codename}-configs.install" ]; then
	    pkg_type="droidian_adapt"
            APT_INSTALL_EXTRA="releng-tools"
	    info "Package type detected: \"${pkg_type}\""
	    ## Import the build droidian package lib
	    # . /usr/lib/${TOOL_NAME}/bdm_plugin_build_droidian_adaptation.sh --run
            ## Configure the droidian package source
            #fn_docker_config_droidian_package_source
	fi
    # Cerca un arxiu README de linux kernel
    elif [ -e "$START_DIR/Makefile" ]; then
	    ## Check if is kernel
            IS_KERNEL=$(cat $START_DIR/Makefile | grep "^KERNELRELEASE =")
            [ -z "${IS_KERNEL}" ] \
	        && abort "No Linux kernel source found in current dir."
            APT_INSTALL_EXTRA="releng-tools"
	    INFO "Kernel source dir detected!"
	    docker_mode="kernel"
	    ## Load berb-build-droidian-kernel.sh
	    info "Cal implementar alguna cosa que sapiga que és kernel droidian"
	    pause "tipus ask What type of kernel source you want to build?"
	    source  /usr/lib/${TOOL_NAME}/bdm_plugin_build_droidian_kernel.sh
	    ## Call kernel source config function
	    fn_docker_config_kernel_source
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

fn_pkg_source_type_detection
fn_docker_plugin_container_conf
fn_bdm_docker_container_config
fn_bdm_docker_global_config
arr_actions_plugin=( "exit" "plugin build ${pkg_type}" )
declare -g arr_data=( "${arr_actions_plugin[@]}" "${arr_actions_base[@]}" )

while [ "${exit}" != "True" ]; do
    fn_bdm_docker_menu_fzf
done

