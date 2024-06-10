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


[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_docker_plugin_container_vars() {
    ## Docker container vars
    CONTAINER_BASE_NAME="build-droidian-env"
    IMAGE_BASE_NAME=""
    IMAGE_BASE_TAG="${host_suite}-${host_arch}"
    CONTAINER_COMMITED_NAME="${CONTAINER_BASE_NAME}"
    IMAGE_COMMIT_NAME='build-droidian-env-upg'
    IMAGE_COMMIT_TAG="${droidian_suite}-${host_arch}"
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
    ## Install apt required packages on container
    APT_INSTALL_REQ="droidian-apt-config droidian-archive-keyring"
    APT_INSTALL_EXTRA="releng-tools"
    fn_install_apt_req
}

fn_build_package_on_container() {
## TODO: Imported from build_debian_package. Needs to be adapted first
    ABORT "Imported from build_debian_package. Needs to be adapted first"
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

<< "IMPORTED_OLD_INITIAL_DROIDIAN-PLUGIN"
# TODO:
## The build adaptation process consists on thre  parts:
# config: (outside docker) The adaptation scripts are used to configure the build env
 # build: (on docker) execute releng-build-package on a container
 # sign: (outside docker) droidian-build-tools script signs the packages
 # recipes creation: src/build-tools/image.sh found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian
 # debs creation: found on:
   # droidian-build-tools/bin/droidian/<vendor>-<code-name>/droidian/apt
    #
    # Set package paths
    droidian_build_tools_fullpath="${START_DIR}/droidian-build-tools/bin"
    adapt_droidian_template_relpath="droidian"
    package_relpath="droidian/${vendor}/${codename}/packages/adaptation-${vendor}-${codename}"
    adapt_droidian_apt_reldir="droidian/${vendor}/${codename}/droidian/apt"
    ## Set paths for docker
    PACKAGE_DIR="${droidian_build_tools_fullpath}/${package_relpath}"
    RESULT_DIR="$(mktemp)"
    LOCAL_REPO_DIR="${droidian_build_tools_fullpath}/${adapt_droidian_apt_reldir}"
    ## Set dirs to mount on the docker container
    buildd_fullpath="${RESULT_DIR}" 
    buildd_sources_fullpath="${PACKAGE_DIR}"
    buildd_local_repo_fullpath="${LOCAL_REPO_DIR}"
    #
    #
    # Configuring the build execution
    build_script_name="build-package-with-droidian-releng.sh"

    ## TODO Recreate the systemd wants links on the sparse directory
    #[ ! -f "create-services-links.sh" ] && abort "create-services-links.sh not found!"
    #./create-services-links.sh
    #
    #@ TODO: Copy the package files to the sparse dir
    #/usr/lib/berb-droidian-build-docker-mgr/cp_pkg_files_2_sparse_dir.sh --run
    #
    ## Copy the  releng caller script to the 
    ## TODO Put in a apt repo and install the package from de docker container

## TODO: DOCKER MGR CONTROL DEPS WITH ADAPT-HELPER
## TODO: APT REPO JAAAA || CREAR DEV TEMPLATE PER A UNES KEYS GPG
## TODO: Solucionar depends releng. Potser fer rebuild posant les meves deps
## TODO: IMPROVE PATH DEL device_info
## TODO: SOLUCIONAR INSTAL:LAR DOCKER MANAGER AL CONTAINER PER TENIR BUILD SCRIPT DIRECTE
## TODO: 
## TODO: SEPARAR FUNCIONS EN ARXIUS DIFERENTS
## TODO: 
## TODO: IMPLEMENTAR MODE ADAPTATION
## TODO: SOLUCIÓ MÉS NETA PER VERSIÓ DE RELENG-BUILD-CHANGELOG
## TODO: ORDENAR PART DEK KERNEL

    cp /usr/lib/berb-droidian-build-docker-mgr/${build_script_name} \
        ${SOURCES_FULLPATH}
    chmod +x ${SOURCES_FULLPATH}/${build_script_name}
    #
    ## Build package on container
    docker exec -it $CONTAINER_NAME bash /buildd/sources/${build_script_name} --run
    #missatge "Docker command is disabled for testing!"
    #
    ## Removing the build script from the package root dir
    rm ${SOURCES_FULLPATH}/${build_script_name}

    info "Build package finished."


IMPORTED_OLD_INITIAL_DROIDIAN-PLUGIN

#fn_plugin_build_debian_package() {
fn_check_for_droidian_build_tools() {
	echo "TODO"
	# AQUI
}
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
       ## Designed for build_debian_package but may be usefull in future
       # fn_update_main_src_file_version_var
    ## Commit the prebuild changes
exit
    fn_bblgit_changelog_commit
    ## Copy the package files to the pkg rootfs dir
       ## Designed for build_debian_package but may be usefull in future
       # fn_copy_files_to_pkg_dir
    ## Call build-package

exit

    fn_build_package_on_container
    #fn_build_package
}
