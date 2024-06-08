#!/bin/bash

## Plugin to automate Droidian adaptation package buildsusing the official Droidian 
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

fn_install_apt_droidian_repos() {
    APT_INSTALL_REQ="droidian-apt-config droidian-archive-keyring"
    fn_install_apt "${APT_INSTALL_REQ}"
}

fn_device_info_load() {
    ## Check file in the user home .config dir
    device_info_filename="device_info.sh"
    dev_info_template_fullpath="/usr/lib/${TOOL_NAME}"
    template="${dev_info_template_fullpath}/${device_info_filename}"
    dev_info_install_fullpath="${HOME}/.config/${TOOL_NAME}"
    install_dir="${dev_info_install_fullpath}"
    install_file="${install_dir}/${device_info_filename}"
    [ ! -d "${install_dir}" ] && mkdir -v "${install_dir}"
    [ ! -f "${install_file}" ] && cp -v "${template}" "${install_dir}"

fn_ask_write_not_set_vars_in_file

}


