#!/bin/bash

## berb-docker-mgr general functions
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


## Config log
fn_bbsl_config_log() {
    ## Prepare log file
    [ -z "${LOG_FULLPATH}" ] && LOG_FULLPATH="${HOME}/logs/${TOOL_NAME}"
    [ ! -d "${LOG_FULLPATH}" ] && mkdir -p "${LOG_FULLPATH}"
    LOG_FILE="${TOOL_NAME}.log"
    echo > "${LOG_FULLPATH}/${LOG_FILE}"
}

#####################
## Print functions ##
#####################
info() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo "INFO: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
INFO() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo; echo "INFO: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
warn() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        echo "WARN: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
WARN() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        echo; echo "WARN: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
debug() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo "DEBUG: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
DEBUG() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo; echo "DEBUG: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
abort() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ABORT ]]; then
        echo "$*"; exit 10 "ABORT: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
ABORT() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ABORT ]]; then
        echo; echo "$*"; exit 10 "ABORT: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
error() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        echo "$*"; exit 1 "ERROR: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
ERROR() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        echo; echo "$*"; exit 1 "ERROR: $*" | tee -a "${LOG_FULLPATH}/${LOG_FILE}" >&2
    fi
}
ask() { read -p "$*" answer; }
ASK() { echo; read -p "$*" answer; }
pause() { read -p "$*"; }
PAUSE() { echo; read -p "$*"; }

########################
## loglevel functions ##
########################

fn_bbl_config_log_level() {
    ## Set the log levels
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARN=2
    readonly LOG_LEVEL_ABORT=3
    readonly LOG_LEVEL_ERROR=4
    ## Search for the log-level flag in the arguments
    for flag in $@; do
        log_level_flag=$(echo "${flag}" | grep "\-\-log\-level")
        if [ -n "${log_level_flag}" ]; then
            LOG_LEVEL=$(echo "${log_level_flag}" | awk -F'=' '{print $2}')
	    DEBUG "Log level flag = \"${LOG_LEVEL}\" found"
	    break
        fi
    done
    ## Set the default log-level if not defined yet
    [ -z "${LOG_LEVEL}" ] && LOG_LEVEL=${LOG_LEVEL_INFO}

}

#######################
## Control functions ##
#######################
fn_check_bash_ver() {
    bash_ver=$(bash --version | head -n 1 \
	| awk '{print $4}' | awk -F'(' '{print $1}' | awk -F'.' '{print $1"."$2"."$3}')
    IFS_BKP=$IFS
    IFS='.' read -r vt_major vt_minor vt_patch <<< "${TESTED_BASH_VER}"
    IFS='.' read -r v_major v_minor v_patch <<< "${bash_ver}"
    IFS=$IFS_BKP
    if [[ $v_major -lt $vt_major ]] || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -lt $vt_minor ]]) || \
           ([[ $v_major -eq $vt_major ]] && [[ $v_minor -eq $vt_minor ]] \
	       && [[ $v_patch -lt $vt_patch ]]); then
    	clear
        WARN "Bash version detected is lower than the tested version"
        warn "If errors are found, try upgrading bash to \"${TESTED_BASH_VER}\" version"
	pause "Press Inro to continue"
    else
        INFO "Bash version requirements are fine"
    fi
}

######################
## Config functions ##
######################
fn_configura_sudo() { [ "$USER" != "root" ] && SUDO='sudo'; }

fn_ask_write_not_set_vars_in_file() {
    ## Search for empty vars in the device config file
    for var in $(cat "${install_file}"); do
        var_not_set=$(echo "${var}" | grep -v "#" | grep -v "=\"" | grep "=")
	if [ -n "${var_not_set}" ]; then
	   info "var_not_set = $var_not_set"
	   ask "\"${var_not_set}\" name is not configured. Please type it: "
           [ -n "${answer}" ] && sed -i \
	       "s/${var_not_set}/${var_not_set}\"${answer}\"/g" "${install_file}"
	fi
    done
    source "${dev_info_install_fullpath}/${device_info_filename}"
}
