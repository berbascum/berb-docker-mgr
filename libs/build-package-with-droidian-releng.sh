#!/bin/bash

# Upstream-Name: berb-droidian-kernel-build-docker-mgr
# Source: https://github.com/droidian-berb/berb-droidian-kernel-build-docker-mgr
  ## Script that manages a custom docker container with Droidian build environment

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
}

fn_set_last_tag() {
    ## Check if the has commit has a tag
    last_commit_tag="$(git tag --contains "HEAD")"
    if [ -z "${last_commit_tag}" ]; then
        clear && info "The last commit has not assigned a tag and is required"
        last_tag=$(git log --decorate | grep 'tag:' | head -n 1 | awk '{print $NF}' | tr -d ')')
        [ -n "${last_tag}" ] \
	   && last_commit_tagged=$(git log --decorate  --abbrev-commit \
	       | grep 'tag:' | head -n 1 | awk '{print $2}') \
           && commit_old_count=$(git rev-list --count HEAD ^"${last_commit_tagged}") \
           && info "The last tag is \"${last_tag}\" and it's \"${commit_old_count}\" commits old"
        [ -z "${last_tag}" ] \
           && info "No git tags found!"
        ask "Enter a tag name in \"<tag_prefix>/<version>\" format or leave empty to cancel: "
        [ -z "${answer}" ] && abort "Canceled by user!"
        input_tag_is_valid=$(echo "${answer}" | grep "\/")
        [ -z "${input_tag_is_valid}" ] && error "The typed tag has not a valid format!"
        last_commit_tag="${answer}"
	info "Creating tag \"${last_commit_tag}\" on the last commit..."
	git tag "${last_commit_tag}"
    fi
}

fn_get_package_info() {
    ## Get the package version and channel distribution from the last commit tag (mandatory)
    package_dist_channel_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $1}')"
    package_version_tag="$(echo "${last_commit_tag}" | awk -F'/' '{print $2}')"
    [ -z "${package_dist_channel}" ] && package_dist_channel="${package_dist_channel_tag}"
    [ -z "${package_version}" ] && package_version="${package_version_tag}"
    info "package_dist_channel = ${package_dist_channel}"
    info "package_version = ${package_version}"
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
    RELENG_FULL_BUILD=yes RELENG_HOST_ARCH=amd64 releng-build-package
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
## Check if the last commit has a tag
fn_set_last_tag
## Get package info
fn_get_package_info
## Patch releng-build-changelog to set the package version and channel from last tag values	
fn_releng_changelog_inject_vars
## Call releng-build-package
fn_build_package
## Restore releng-build-changelog vars previously patched
fn_releng_changelog_restore_vars
