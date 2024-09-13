#!/bin/bash

## build Sub-Plugin to automate Droidian rootfs creation 

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

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_docker_plugin_container_vars() {
    ## Docker container vars
    fn_bdm_conf_file_load "CONF_USER_DROIDIAN" "docker-container-adapt-vars"
    CONTAINER_BASE_NAME="build-droidian-env-${package_name}"
    IMAGE_BASE_NAME='quay.io/droidian/rootfs-builder'
    IMAGE_BASE_TAG="current-${droidian_host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='droidian/rootfs-builder-upg'
    IMAGE_COMMIT_TAG="current-${droidian_host_arch}"
    ## Paths configuration
    #
    SOURCES_FULLPATH="${START_DIR}"
    OUTPUT_FULLPATH="${SOURCES_FULLPATH}/images"
    ## Create the output dir
    [ -d "${OUTPUT_FULLPATH}" ] ||  mkdir -v "${OUTPUT_FULLPATH}"
        #PACKAGES_DIR="${OUTPUT_FULLPATH}"
        #buildd_fullpath="${PACKAGES_DIR}" 
        #buildd_sources_fullpath="${SOURCES_FULLPATH}"
}

fn_docker_plugin_container_conf() {
    debug "fn_docker_plugin_container_conf has no any code yet!"
}

fn_build_package_on_container() {
    # Configuring the build script
    [ -f "${SOURCES_FULLPATH}/${BUILD_SCRIPT_NAME}" ] && rm ${SOURCES_FULLPATH}/${BUILD_SCRIPT_NAME}
    [ ! -f "${BUILD_SCRIPT_FULLPATH_FILE}" ] && error "Build script template not found!"
    cp "${BUILD_SCRIPT_FULLPATH_FILE}" "${SOURCES_FULLPATH}"

    ## Set x permissions
    chmod +x ${SOURCES_FULLPATH}/${BUILD_SCRIPT_NAME}
    ## Config the releng arch in the build launcher
    sed -i "s/RELENG_HOST_ARCH=\".*\"/RELENG_HOST_ARCH=\"${releng_host_arch}\"/g" \
	${SOURCES_FULLPATH}/${BUILD_SCRIPT_NAME}
    ## Build package on container
    docker exec -it $CONTAINER_NAME bash /buildd/sources/${BUILD_SCRIPT_NAME} --run
    ## Remove the build script
    #rm ${SOURCES_FULLPATH}/${BUILD_SCRIPT_NAME}
    ## Some output files may have owned by root, fixing:
    ${SUDO} chown -R ${USER}: "${OUTPUT_FULLPATH}"

    INFO "Build package finished."
}

fn_plugin_sub_exec()  {
    ## Check the git workdir status and abort if not clean
#    fn_bblgit_workdir_status_check
    ## Check origin status, an updated branch in origin is required
#    fn_bblgit_origin_status_ckeck
    ## Check if the last commit has a tag
#    fn_bblgit_last_two_tags_check
    ## Get package info
#    fn_get_package_info
    ## Copy the package files to the pkg rootfs dir
       ## Designed for build_debian_package but may be usefull in future
#       fn_copy_files_to_pkg_dir
    ## Create the tag from user input
#    fn_bblgit_create_tag
    ## Check origin status, an updated branch in origin is required
#    fn_bblgit_origin_status_ckeck
    ## Call build-package
    fn_build_package_on_container
}
