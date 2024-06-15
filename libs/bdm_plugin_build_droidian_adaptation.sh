#!/bin/bash

## build Sub-Plugin to automate Droidian adaptation package builds using the official Droidian 

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

## some notes ##
## The build adaptation process consists on thre  parts:
# new-template: (outside docker) The adaptation scripts are used to create a new device temp
 # build: (on docker) execute releng-build-package on a container
 # sign: (outside docker) droidian-build-tools script signs the packages
 # recipes creation: src/build-tools/image.sh found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian
 # debs creation: found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian/apt

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_docker_plugin_container_vars() {
    ## Docker container vars
    fn_bdm_conf_file_load "CONF_USER_DROIDIAN" "docker-container-vars"
    CONTAINER_BASE_NAME="build-droidian-env-${package_name}"
    IMAGE_BASE_NAME='quay.io/droidian/build-essential'
    IMAGE_BASE_TAG="${droidian_host_suite}-${droidian_host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='droidian/build-essential-upg'
    IMAGE_COMMIT_TAG="${droidian_host_suite}-${droidian_host_arch}"
    ## Paths configuration
    SOURCES_FULLPATH="${START_DIR}"
    OUTPUT_FULLPATH="${SOURCES_FULLPATH}/out-${package_name}"
        #PACKAGES_DIR="${OUTPUT_FULLPATH}"
        #buildd_fullpath="${PACKAGES_DIR}" 
        #buildd_sources_fullpath="${SOURCES_FULLPATH}"
    ## Create the output dir
    [ -d "${OUTPUT_FULLPATH}" ] || mkdir -v "${OUTPUT_FULLPATH}"
    
    # Set droidian adaptation specific paths
    droidian_build_tools_relpath="droidian-build-tools/bin"
    droidian_build_tools_fullpath="${START_DIR}/${droidian_build_tools_relpath}"
    adapt_droidian_template_relpath="droidian"
    #pkg_relpath="droidian/${vendor}/${codename}/packages/adaptation-${vendor}-${codename}"
    adapt_droidian_apt_reldir="droidian/${vendor}/${codename}/droidian/apt"
    ## Set droidian adaptation paths for docker container
    PACKAGE_DIR="${SOURCES_FULLPATH}"
    RESULT_DIR="${OUTPUT_FULLPATH}"
    LOCAL_REPO_DIR="${droidian_build_tools_fullpath}/${adapt_droidian_apt_reldir}"
    ## Set dirs to mount on the docker container
    buildd_fullpath="${RESULT_DIR}" 
    buildd_sources_fullpath="${PACKAGE_DIR}"
    buildd_local_repo_fullpath="${LOCAL_REPO_DIR}"
    fn_docker_plugin_build_droidian_adapt_tools_prep
}

fn_docker_plugin_build_droidian_adapt_tools_prep() {
    [ ! -d "${droidian_build_tools_relpath}" ] \
	&& WARN "dir ./${droidian_build_tools_relpath} not exist" \
	&& warn "If you have a backup with the device template created, extract here" \
	&& warn "or create a new device droidian template!" \
	&& error "Aborting..."
}

fn_docker_plugin_container_conf() {
    ## Add systemd services from pkg_rootfs_dir/etc/systemd/system to .links and .dir files
    fn_plugin_build_main_pkg_rootfs_systemd_links_add "${pkg_rootfs_dir}"
    #debug "fn_docker_plugin_container_conf has no any code yet!"
}

fn_build_package_on_container() {
    # Configuring the build script
    build_script_name="build-package-with-droidian-releng.sh"
    bdm_url_base="https://raw.githubusercontent.com/berbascum/berb-docker-mgr"
    bdm_url_build_script_relpath="sid/libs/${build_script_name}"
    ## Download the build launcher script
    rm ${SOURCES_FULLPATH}/${build_script_name}
    wget "${bdm_url_base}/${bdm_url_build_script_relpath}"
    ## Set x permissions
    chmod +x ${SOURCES_FULLPATH}/${build_script_name}
    ## Config the releng arch in the build launcher
    sed -i "s/RELENG_HOST_ARCH=\".*\"/RELENG_HOST_ARCH=\"${releng_host_arch}\"/g" \
	${SOURCES_FULLPATH}/${build_script_name}
    ## Build package on container
    docker exec -it $CONTAINER_NAME bash /buildd/sources/${build_script_name} --run
    ## Remove the build script
    rm ${SOURCES_FULLPATH}/${build_script_name}
    ## Some output files may have owned by root, fixing:
    ${SUDO} chown -R ${USER}: "${OUTPUT_FULLPATH}"

    INFO "Build package finished."
}

fn_plugin_sub_exec()  {
    ## Check the git workdir status and abort if not clean
    fn_bblgit_workdir_status_check
    ## Check origin status, an updated branch in origin is required
    fn_bblgit_origin_status_ckeck
    ## Check if the last commit has a tag
    fn_bblgit_last_two_tags_check
    ## Get package info
#    fn_get_package_info
    ## Copy the package files to the pkg rootfs dir
       ## Designed for build_debian_package but may be usefull in future
#       fn_copy_files_to_pkg_dir
    ## Commit the updated $pkg_rootfs packacing dir
##    fn_bblgit_commit_changes "${pkg_rootfs_dir}" "Update: pkg_rootfs_dir packaging dir contents"
    ## Build the change log from the git history
#    fn_bblgit_changelog_build
    ## Update version and channel on the main src file
       ## Designed for build_debian_package but may be usefull in future
#       fn_update_main_src_file_version_var
    ## Commit the prebuild changes
#    fn_bblgit_changelog_commit
    ## Create the tag from user input
    fn_bblgit_create_tag
    ## Call build-package
    fn_build_package_on_container
}
