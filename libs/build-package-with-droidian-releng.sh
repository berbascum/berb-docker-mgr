#!/bin/bash

# Upstream-Name: berb-droidian-build-docker-mgr
# Source: https://github.com/droidian-berb/berb-droidian-build-docker-mgr
  ## Script to configure a debian package to be builded with the droidian releng-tools

# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
# All rights reserved.

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


info() { echo; echo "$*"; }
error() { echo; echo "$*"; exit 1; }
abort() { echo; echo "$*"; exit 10; }
ask() { echo; read -p "$*" answer; }

[ -z "$(echo "$*" | grep "\-\-run")" ] && abort "The script tag --run is required!"

fn_config_global() {
    chmod +x /buildd/sources/debian/rules
    cd /buildd/sources
    package_name=$(cat debian/control | grep "^Source: " | awk '{print $2}')
}

fn_workdir_status_check() {
    [ -n "$(git status | grep "staged")" ] && abort "The git workdir is not clean!"
}

fn_releng_changelog_inject_vars() {
    ## Patch starting_version on releng-build-changelog with the last tag value
    sed -i \
        "s|starting_version = strategy()|starting_version = "\"${package_version}\"" #RESTORE|g" \
        /usr/lib/releng-tools/build_changelog.py
    ## Patch self.comment on releng-build-changelog with the last tag value
    sed -i \
	"s|self.comment = slugify(comment.*|self.comment = "\"${package_dist_channel}\"" #RESTORE|g" \
	/usr/lib/releng-tools/build_changelog.py
}

fn_build_package() {
    ## Call releng
    RELENG_FULL_BUILD="yes" RELENG_HOST_ARCH="amd64" releng-build-package
    ## TODO: #RELENG_TAG_PREFIX=  RELENG_BRANCH_PREFIX
}

fn_releng_changelog_restore_vars() {
    ## Restore patched startin_version on releng-build-changelog
    sed -i "s|starting_version = .*RESTORE|starting_version = strategy()|g" \
	/usr/lib/releng-tools/build_changelog.py
    ## Restore patched self.comment on releng-build-changelog
    sed -i \
	"s|self.comme.*RESTORE|self.comment = slugify(comment.replace(self.branch_prefix, \"\"))|g" \
	/usr/lib/releng-tools/build_changelog.py
}

## Load global conf
fn_config_global
## Check the git workdir status and abort if not clean
fn_workdir_status_check
## Check if the last commit has a tag
#fn_set_last_tag
## Get package info
## Patch releng-build-changelog to set the package version and channel from last tag values
# fn_releng_changelog_inject_vars
## Call releng-build-package
fn_build_package
## Restore releng-build-changelog vars previously patched
# fn_releng_changelog_restore_vars
