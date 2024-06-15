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
. /usr/lib/berb-bash-libs/bbl_git_lib_${BBL_GIT_VERSION}

fn_get_package_info() {
    ## Get the package version and channel distribution from the last commit tag (mandatory)
    pkg_dist_channel_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $1}')"
    package_version_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $2}')"
    [ -z "${pkg_dist_channel}" ] && pkg_dist_channel="${pkg_dist_channel_tag}"
    [ -z "${package_version}" ] && package_version="${package_version_tag}"
    package_version_int=$(echo ${package_version} | sed s/"\."/""/g)
    info "pkg_dist_channel = ${pkg_dist_channel}"
    info "package_version = ${package_version}"
}

fn_update_main_src_file_version_var() {
    ## Update the TOOL_VERSION value on the main source file with the last tag version
    ## Firts, if not exist a script ${package_name}.sh exit the function
    [ -n "${package_name}.sh" ] && return
    if [ -n $(cat "${package_name}.sh" | grep "^#TOOL_VERSION=\"") ]; then
        tool_vers_var_name="#TOOL_VERSION"
    elif [ -n $(cat "${package_name}.sh" | grep "^TOOL_VERSION=\"") ]; then
	tool_vers_var_name="TOOL_VERSION"
    else
        tool_vers_var_name=""
    fi
    if [ -n "${tool_vers_var_name}" ]; then
        sed -i "s/^${tool_vers_var_name}=\".*/${tool_vers_var_name}=\"${package_version}\"/g" "${package_name}.sh"
    fi
    ## Update the TOOL:CHANNEL value on the main source file with the last tag version
    if [ -n $(cat "${package_name}.sh" | grep "^#TOOL_CHANNEL=\"") ]; then
        tool_vers_var_name="#TOOL_CHANNEL"
    elif [ -n $(cat "${package_name}.sh" | grep "^TOOL_CHANNEL=\"") ]; then
	tool_vers_var_name="TOOL_CHANNEL"
    else
        tool_vers_var_name=""
    fi
    if [ -n "${tool_vers_var_name}" ]; then
        sed -i "s/^${tool_vers_var_name}=\".*/${tool_vers_var_name}=\"${pkg_dist_channel}\"/g" "${package_name}.sh"
    fi
}
fn_copy_files_to_pkg_dir() {
    ASK "Want to copy the existing package files to the pkg_rootfs dir? [ y/n ]: "
    [ "${answer}" != "y" ] && debug "Copy to pkg_rootfs canceled by user!" && return
    ## Get the upsetream name from debian/changelog
    [ ! -f "debian/copyright" ] && error "debian/copyright file not found"
    upstream_name="$(cat debian/copyright | grep "^Upstream-Name:" | awk -F': ' '{print $2}')"
    ## Create dirs on pkg rootfs dir
    debian_install_exist=$(find "./debian" -maxdepth 1 -name "*.install")
    [ -z "${debian_install_exist}" ] && error "No debian package install files found"
    ASK "Want to clean the pkg_rootfs content first? [ y/n ]: "
    [ "${answer}" == "y" ] && rm -r -v ${pkg_rootfs_dir}/*
    info "Copying the package files to the pkg rootfs dir..."
    ## Create pkg_rootfs dirs from debian packaging dirs files
    IFS=$' \t\n'
    for dirs_file in $(find ./debian -maxdepth 1 -name "*.dirs"); do
	debug "\"${dirs_file}\" file found!"
        dirs_basename=$(basename "${lib}")
        dirs_basename_noext=$(echo "${dirs_basename}" | awk -F'.' '{print $1}')
        if [ -f "${dirs_file}" ]; then 
            while read dir; do
	        debug "Creating \"${dir}\" dir..."
                [ ! -d "${pkg_rootfs_dir}${dir}" ] && mkdir -p ${pkg_rootfs_dir}${dir}
            done <${dirs_file}
        fi
    done
    ## Copy the main script if found to the pkg rootfs dir
    [ -f "${upstream_name}.sh" ] && cp -av ${upstream_name}.sh ${pkg_rootfs_dir}/usr/bin/${upstream_name}
    ## Copy the lib files if found to the pkg rootfs dir
    if [ -d "libs" ]; then
        IFS=$' \t\n'
        for lib in $(find ./libs -maxdepth 1 -name "*.sh"); do
            lib_basename=$(basename "${lib}")
            lib_basename_noext=$(echo "${lib_basename}" | awk -F'.' '{print $1}')
            cp -av "${lib}" "${pkg_rootfs_dir}/usr/lib/${upstream_name}/${lib_basename_noext}"
        done
    fi
    #
    ## Copy the lib/modules files if found to the pkg rootfs dir
    if [ -d "libs/modules" ]; then
        IFS=$' \t\n'
        for lib_module in $(find ./libs/modules -name "*.sh"); do
            lib_basename=$(basename "${lib_module}")
            lib_basename_noext=$(echo "${lib_basename}" | awk -F'.' '{print $1}')
            cp -av "${lib_module}" \
                "${pkg_rootfs_dir}/usr/lib/${upstream_name}/${lib_basename_noext}_${package_version_int}"
        done
    fi
    ## Copy the conf files if found to the pkg rootfs dir
    [ -d "conf" ] && cp -av conf/*  ${pkg_rootfs_dir}/etc/${upstream_name}
    ## Copy the conf template files if found to the pkg rootfs dir
    [ -d "conf_templates" ] && cp -av conf_templates/*  ${pkg_rootfs_dir}/usr/share/${upstream_name}
    PAUSE "Copy to pkg rootfs process finished. Press Intro to continue "
}

fn_plugin_build_main_pkg_rootfs_systemd_links_add() {
    ## Add the systemd wants links from pkg rootfs dir to debian .links and .dirs
    ## Set paths
    pkg_rootfs_dir="$1"
    systemd_etc_dir="etc/systemd/system"
    pkg_systemd_etc_dir="${pkg_rootfs_dir}/${systemd_etc_dir}"
    info "Adding systemd wants links from pkg rootfs dir to debian .links and .dirs..."
    ## Check for systemd dir in the pkg_rootfs dir
    [ ! -d "${pkg_systemd_etc_dir}" ] \
	&& info "No etc/systemd dir found in pkg_rootfs" && return
    ## Search for debian pkging .links file
    arr_pkg_links_file=( $(find debian/ -name "${package_name}*.links") )
    [ "${#arr_pkg_links_file[@]}" -eq "0" ] \
	&& warn "No .links file in debian dir" && return
    [ "${#arr_pkg_links_file[@]}" -gt "1" ] \
	&& warn "Many .links files in debian dir" && return
    pkg_links_file="${arr_pkg_links_file[0]}"
    debug "Length arr_pkg_links_file = ${#arr_pkg_links_file[@]}" 
    ## Search for debian pkging .dirs file
    arr_pkg_dirs_file=( $(find debian/ -name "${package_name}*.dirs") )
    [ "${#arr_pkg_dirs_file[@]}" -eq "0" ] \
	&& warn "No .dirs file in debian dir" && return
    [ "${#arr_pkg_dirs_file[@]}" -gt "1" ] \
	&& warn "Many .dirs files in debian dir" && return
    pkg_dirs_file="${arr_pkg_dirs_file[0]}"
    debug "Length arr_pkg_dirs_file = ${#arr_pkg_dirs_file[@]}" 
    #
    ## Search for systemd services in the pkg_rootfs dir
    arr_service_files=()
    while IFS= read -r -d '' file; do
        arr_service_files+=("$file")
    done < <(find "${pkg_systemd_etc_dir}" -maxdepth 1 -name "*.service" -print0)
    debug "arr_service_files[0] = ${arr_service_files[0]}"
    #
    ## Add systemd service links to the debian/adaptation.links
    arr_services_wanted=()
    for service_file in ${arr_service_files[@]}; do
        service_file_basename=$(basename "${service_file}")
        service_name="${service_file_basename%%.*}"
	debug "service_file = ${service_file}"
        ## Search for wanted_by var on each service file and get its value
        wanted_by=$(cat "${service_file}" | grep "WantedBy" | awk -F'=' '{print $2}')
	debug "wanted_by = ${wanted_by}"
        [ -z "${wanted_by}" ] && continue
	## Add wanted_by to an array without dups, to add the dirs in the debian .dirs file
	wanted_dup=$(echo "${arr_services_wanted[*]}" | grep "${wanted_by}")
	[ -z "${wanted_dup}" ] && arr_services_wanted+=( "${wanted_by}" )
	## Check if the service was previouslu added
	link_found=$(cat ${pkg_links_file} | grep "${service_file_basename}")
	debug "link_found = \"${link_found}\" if empty, service will be added"
        [ -n "${link_found}" ] && continue
	## Add the service link to the debian .links file
        echo "/${systemd_etc_dir}/${service_file_basename} /${systemd_etc_dir}/${wanted_by}.wants/${service_file_basename}" >> ${pkg_links_file}
    done
    ## Add wanted dir in debian/.dirs file
    debug "Length arr_services_wanted = ${#arr_services_wanted[@]}"
    for service_wanted in "${arr_services_wanted[@]}"; do
	## Check if the wanted dir was previouslu added
	wanted_dir_found=$(cat ${pkg_dirs_file} | grep "${service_wanted}")
	debug "wanted_dir_found = \"${wanted_dir_found}\" if empty, dir will be added"
        [ -n "${wanted_dir_found}" ] && continue
	## Add the service link to the debian .links file
        echo "/${systemd_etc_dir}/${service_wanted}.wants" >> ${pkg_dirs_file}
    done
    info "Finished adding systemd wants links on debian .links and .dirs"
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
    debug "dir .git and debian/control checks passed"
    # Cerca el dir pkg_rootfs
    if [ -e "${START_DIR}/pkg_rootfs" ]; then
	## Set docker mode
	docker_mode="package"
	pkg_type="debian_package"
	pkg_rootfs_dir="pkg_rootfs"
	info "Package type detected: \"${pkg_type}\""
	## Source the corresponding pkg_type lib
	. ${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_${pkg_type}.sh --run
    # Cerca el dir sparse
    elif [ -e "${START_DIR}/sparse" ]; then
	## Set docker mode
	docker_mode="package"
	pkg_rootfs_dir="sparse"
	debug "sparse dir detected, checking type..."
	## sparse dir found, may be a droidian package
	[ ! -f "${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_droidian_main.sh" ] \
	    && abort "build_droidian_main library not found!"
	debug "May be a Droidian package, loading build_droidian_main lib..."
	. ${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_droidian_main.sh --run
        fn_plugin_build_droidian_main_set_user_config
        fn_plugin_build_droidian_main_load_device_vars
	#
	## Get the package type
	if [ -f "debian/adaptation-${vendor}-${codename}-configs.install" ]; then
	    pkg_type="droidian_adaptation"
	    debug "Package type detected: \"${pkg_type}\""
	    ## Import the build droidian package lib
	    [ ! -f "${LIBS_FULLPATH}/bdm_plugin_${plugin_enabled}_${pkg_type}.sh" ] \
	        && error "build_droidian_adaptation library not found!"
	    debug "Loading plugin_build_${pkg_type} lib..."
	    . /usr/lib/${TOOL_NAME}/bdm_plugin_${plugin_enabled}_${pkg_type}.sh --run
        else
	    abort "Package is using sparse dir model, but type is not recognized!"
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

fn_plugin_build_main_docker_container_reqs() {
    ## Check that the container name is created
    if [ -z "$(docker ps -a | grep "${CONTAINER_NAME}")" ]; then
        INFO "The docker container needs to be previously created"
        ASK "Want to create \"${CONTAINER_NAME}\" docker container? [ y/n ]: "
        [ "${answer}" != "y" ] && abort "Aborted by user"
	fn_bdm_docker_create_container
    fi
    ## Check that the container name is started
    if [ -z "$(docker ps | grep "${CONTAINER_NAME}")" ]; then
        INFO "The docker container needs to be previously started!"
        ASK "Want to start \"${CONTAINER_NAME}\" docker container? [ y/n ]: "
        [ "${answer}" != "y" ] && abort "Aborted by user"
        fn_bdm_docker_start_container
    fi
}

<< "NOT_USED_YET"
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
NOT_USED_YET


## Script execution
fn_pkg_source_type_detection
fn_docker_plugin_container_vars
fn_bdm_docker_container_config
fn_plugin_build_main_docker_container_reqs

fn_docker_plugin_container_conf
fn_bdm_docker_main_menu
arr_actions_plugin=( "exit" "plugin build ${pkg_type}" )
declare -g arr_data=( "${arr_actions_plugin[@]}" "${arr_actions_base[@]}" )

while [ "${exit}" != "True" ]; do
    fn_bdm_docker_menu_fzf
done

