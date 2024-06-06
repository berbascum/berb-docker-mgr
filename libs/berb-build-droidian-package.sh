#!/bin/bash

## Plugin to automate Droidian kernel compilations using the official Droidian 
## build tools and docker containers managed by the main script.

# Upstream-Name: berb-droidian-build-docker-mgr
# Source: https://github.com/droidian-berb/berb-droidian-build-docker-mgr
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


fn_docker_config_droidian_build_tools_package() {
    APT_INSTALL_EXTRA="releng-tools"
    
    ## Load device_info vars
    fn_device_info_load

    # Set package paths
    SOURCES_FULLPATH="${START_DIR}"

    ## Call configurer for the detected package type
    fn_docker_config_${pkg_type}_source
}
export -f fn_docker_config_droidian_build_tools_package

fn_docker_config_standard_pkg_source() {
    OUTPUT_FULLPATH="${SOURCES_FULLPATH}/out-${package_name}"
    PACKAGES_DIR="${OUTPUT_FULLPATH}"
    buildd_fullpath="${PACKAGES_DIR}" 
    buildd_sources_fullpath="${SOURCES_FULLPATH}"
    ## Create the output dir
    [ -d "$PACKAGES_DIR" ] || mkdir -v $PACKAGES_DIR
}

fn_check_for_droidian_build_tools() {
	echo "TODO"
	# AQUI
}
fn_docker_config_droidian_adapt_source() {
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

#AQUI

}

fn_build_package_on_container() {
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


<< "ADAPTATION_IN_DEVELOPMENT"
AQUI


## Global config
bkp_private_filename="backup-droidian-private-gpg-apt-${vendor}-${codename}.tar.gz"
bkp_template_filename="backup-droidian-adaptation-fresh-template-${vendor}-${codename}.tar.gz"
bkp_adapt_git_repo_filename="backup-droidian-adaptation-git-repo-${vendor}-${codename}.tar.gz"
build_tools_droidian_fullpath="${START_DIR}/droidian-build-tools/bin"
build_tools_src_fullpath="${START_DIR}/droidian-build-tools/bin/src/build-tools"
build_private_fullpath="${START_DIR}/droidian-build-tools/bin/droidian/${vendor}/${codename}/private"
build_adaptation_fullpath="${START_DIR}/droidian-build-tools/bin/droidian/${vendor}/${codename}/packages/adaptation-${vendor}-${codename}"

## Extract the full droidian-build-package with the template
[ ! -f "${bkp_template_filename}" ] && abort "Build template ${bkp_template_filename} not found!"
[ ! -d "${START_DIR}/droidian-build-tools" ] && cd ${START_DIR} && tar zxf "${bkp_template_filename}"
## Update the suite to trixie on droidian-build-tools
#sed -i 's/bookworm/trixie/g' ${build_tools_src_fullpath}/common.sh

## create link to the adaptation git repo on the droidian-build-tools structure
[ -d "${build_adaptation_fullpath}" ] && mv ${build_adaptation_fullpath} ${build_adaptation_fullpath}_bkp \
    && ln -s "${START_DIR}" "${build_adaptation_fullpath}"
[ -L "${build_adaptation_fullpath}" ] && rm "${build_adaptation_fullpath}" \
    && ln -s "${START_DIR}" "${build_adaptation_fullpath}"

## Build the adaptation packages
## by default arm64 host arch is defined. To use adm64 add "-b amd64" flag
cd ${build_adaptation_fullpath} && ${build_tools_droidian_fullpath}/droidian-build-package -b amd64
cd ${START_DIR}
ADAPTATION_IN_DEVELOPMENT

}
export -f fn_build_package_on_container
