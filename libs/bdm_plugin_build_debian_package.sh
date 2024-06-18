#!/bin/bash

## build Sub-Plugin to build a debian package from the files in the current dir
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


[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_docker_plugin_container_vars() {
    ## Docker container vars
    fn_bdm_conf_file_load "CONF_USER_MAIN" "docker-container-vars"
    CONTAINER_BASE_NAME="berb-build-env-${package_name}"
    IMAGE_BASE_NAME="ghcr.io/berbascum/berb-build-env"
    IMAGE_BASE_TAG="${host_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='berb-build-env-upg'
    IMAGE_COMMIT_TAG="${host_suite}-${host_arch}"
    ## Paths configuration
    SOURCES_FULLPATH="${START_DIR}"
    OUTPUT_FULLPATH="${SOURCES_FULLPATH}/out-${package_name}"
    PACKAGES_DIR="${OUTPUT_FULLPATH}"
    buildd_fullpath="${PACKAGES_DIR}" 
    buildd_sources_fullpath="${SOURCES_FULLPATH}"
    ## Create the output dir
    [ -d "$PACKAGES_DIR" ] || mkdir -v $PACKAGES_DIR
}

fn_docker_plugin_container_conf() {
    ## Add systemd services from pkg_rootfs_dir/etc/systemd/system to .links and .dir files
    fn_plugin_build_main_pkg_rootfs_systemd_links_add "${pkg_rootfs_dir}"
    #debug "fn_docker_plugin_container_conf has no any code yet!"
}

fn_build_package() {
    dpkg-buildpackage -us -uc
    INFO "Build package finished."
}

fn_build_package_on_container() {
    ## Usefull vars
    #export DEB_BUILD_OPTIONS="parallel=$(nproc)"
    #export DEB_HOST_ARCH=arm64
    #export CC=aarch64-linux-gnu-gcc
    #export CXX=aarch64-linux-gnu-g++
    #export PATH=/usr/aarch64-linux-gnu/bin:$PATH
    #export CROSS_COMPILE=aarch64-linux-gnu-
    #
    script="build-debian-package.sh"
    ## Create a build launcher and copy to the sources dir
    echo "#!/bin/bash" > ${SOURCES_FULLPATH}/${script}
    echo >> ${SOURCES_FULLPATH}/${script}
    echo "cd /buildd/sources" >> ${SOURCES_FULLPATH}/${script}
    if [ "${CROSS_ENABLE}" == "True" ]; then
        echo >> ${SOURCES_FULLPATH}/${script}
        echo "## Cross compile vars" >> ${SOURCES_FULLPATH}/${script}
        echo "export DEB_HOST_ARCH=${target_arch}" >> ${SOURCES_FULLPATH}/${script}
        echo "export CC=${cross_arch}-linux-gnu-gcc" >> ${SOURCES_FULLPATH}/${script}
        echo "export CXX=${cross_arch}-linux-gnu-g++" >> ${SOURCES_FULLPATH}/${script}
        echo "export CROSS_COMPILE=${cross_arch}-linux-gnu-" >> ${SOURCES_FULLPATH}/${script}
        echo "## Build package" >> ${SOURCES_FULLPATH}/${script}
        echo "dpkg-buildpackage -us -uc -Pcross" >> ${SOURCES_FULLPATH}/${script}
    else
        echo "## Build package" >> ${SOURCES_FULLPATH}/${script}
        echo "dpkg-buildpackage -us -uc" >> ${SOURCES_FULLPATH}/${script}
    fi
    ## Set x permissions
    chmod +x ${SOURCES_FULLPATH}/${script}
    ## Exec command
    docker exec $CONTAINER_NAME bash /buildd/sources/${script}
    #rm ${SOURCES_FULLPATH}/${script}
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
    fn_get_package_info
    ## Update version and channel on the main src file
    fn_update_main_src_file_version_var
    ## Copy the package files to the pkg rootfs dir
    fn_copy_files_to_pkg_dir
    ## Build the change log from the git history
    fn_bblgit_changelog_build
    ## Commit the updated files before building
    fn_bblgit_commit_changes \
	"Build release: pre-configs before building new version ${tag_version}-${tag_release}"
    ## Create the tag from user input
    fn_bblgit_create_tag
    ## Check origin status, an updated branch in origin is required
    fn_bblgit_origin_status_ckeck
    ## Call build-package
    fn_build_package_on_container
    #fn_build_package
}

