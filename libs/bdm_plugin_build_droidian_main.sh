#!/bin/bash

## build Sub-PluginMain to apply shared configs for the droidian build sub-plugins

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


fn_plugin_build_droidian_main_set_user_config() {
    ## Set SubPlugin build_droidian user conf file name
    CONF_USER_DROIDIAN_FILENAME="bdm-user-droidian.conf"
    CONF_USER_DROIDIAN_FULLPATH_FILENAME="${CONF_USER_FULLPATH}/${CONF_USER_DROIDIAN_FILENAME}"
    #
    ## Check and install SubPlugin build_droidian user conf file
    fn_bdm_conf_file_install "${CONF_USER_FULLPATH}" "${CONF_USER_DROIDIAN_FILENAME}"
}

fn_plugin_build_droidian_main_load_device_vars() {
    fn_bdm_conf_file_ask_empty_vars "CONF_USER_DROIDIAN" "device-vars"
    fn_bdm_conf_file_load "CONF_USER_DROIDIAN" "device-vars"
}
