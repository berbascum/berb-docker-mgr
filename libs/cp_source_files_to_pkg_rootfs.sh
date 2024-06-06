#!/bin/bash

## Script to copy the package files to the sparse dir
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


error() { echo; echo "$*"; exit 1; }
abort() { echo; echo "$*"; exit 10; }
info() { echo; echo "$*"; }

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_main_exec() {
    ## Search for debian/control
    [ ! -f "./debian/control" ] && error "debian/control not found!"
    package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')

    ## Create dirs on sparse
    debian_package_dirs_file_relpath="debian/${package_name}.dirs"
    [ ! -f "${debian_package_dirs_file_relpath}" ] && error "debian package dirs file not found!"
    for dir in $(cat ${debian_package_dirs_file_relpath}); do
        [ ! -d "sparse${dir}" ] && mkdir -p -v sparse${dir}
    done

    ## Copy files on sparse
    cp -v ${package_name}.sh sparse/usr/bin/${package_name}
    cp -v libs/*  sparse/usr/lib/${package_name}/
}

## Main execution
fn_main_exec
