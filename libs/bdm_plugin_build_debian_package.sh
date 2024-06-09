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

fn_docker_plugin_container_conf() {
    # docker_mode="package" ##Es defineix al build_main  
    ## Docker constants
    CONTAINER_BASE_NAME="berb-build-env"
    IMAGE_BASE_NAME="ghcr.io/berbascum/berb-build-env"
    IMAGE_BASE_TAG="${host_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='berb/build-essential'
    IMAGE_COMMIT_TAG="${droidian_suite}-${host_arch}"
}

fn_build_package() {
    dpkg-buildpackage -us -uc
    INFO "Build package finished."
}

fn_build_package_on_container() {
    docker exec -it $CONTAINER_NAME bash dpkg-buildpackage -us -uc
    INFO "Build package finished."
}

#fn_plugin_build_debia_package() {
fn_plugin_sub_exec()  {
    ## Check the git workdir status and abort if not clean
    fn_bblgit_workdir_status_check
    ## Check if the last commit has a tag
    fn_bblgit_last_two_tags_check
    ## Get package info
    fn_get_package_info
    ## Build the change log from the git history
    fn_bblgit_changelog_build
    ## Update version and channel on the main src file
    fn_update_main_src_file_version_var
    ## Commit the prebuild changes
    fn_bblgit_changelog_commit
    ## Copy the package files to the pkg rootfs dir
    fn_copy_files_to_pkg_dir
    ## Call build-package
    fn_build_package_on_container
    #fn_build_package
}

