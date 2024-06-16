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
    #
    ## Create a build launcher and copy to the sources dir
    echo "#!/bin/bash" > ${SOURCES_FULLPATH}/build-debian-package.sh
    echo >> ${SOURCES_FULLPATH}/build-debian-package.sh
    echo "cd /buildd/sources" >> ${SOURCES_FULLPATH}/build-debian-package.sh
    echo >> ${SOURCES_FULLPATH}/build-debian-package.sh
    echo "dpkg-buildpackage -us -uc" >> ${SOURCES_FULLPATH}/build-debian-package.sh
    ## Set x permissions
    chmod +x ${SOURCES_FULLPATH}/build-debian-package.sh
    docker exec -it $CONTAINER_NAME bash /buildd/sources/build-debian-package.sh
    rm ${SOURCES_FULLPATH}/build-debian-package.sh
    INFO "Build package finished."
}

#fn_plugin_build_debia_package() {
fn_plugin_sub_exec()  {
    ## Check the git workdir status and abort if not clean
    fn_bblgit_workdir_status_check
    ## Check origin status, an updated branch in origin is required
    fn_bblgit_origin_status_ckeck
    ## Check if the last commit has a tag
    fn_bblgit_last_two_tags_check
    ## Get package info
    fn_get_package_info
    ## Copy the package files to the pkg rootfs dir
    fn_copy_files_to_pkg_dir
    ## Commit the updated $pkg_rootfs packacing dir
    fn_bblgit_commit_changes "${pkg_rootfs_dir}" "Update pkg_rootfs_dir packaging dir contents"
    ## Update version and channel on the main src file
    fn_update_main_src_file_version_var
    ## Commit the update new version changes
    fn_bblgit_commit_changes "${main_src_relpath_file}" "Update new version num and release"
    ## Build the change log from the git history
    fn_bblgit_changelog_build
    ## Commit the updated changelog
    fn_bblgit_commit_changes "debian/changelog" "Update debian changelog"
    ## Create the tag from user input
    fn_bblgit_create_tag
    ## Check origin status, an updated branch in origin is required
    fn_bblgit_origin_status_ckeck
    ## Call build-package
    fn_build_package_on_container
    #fn_build_package
}

