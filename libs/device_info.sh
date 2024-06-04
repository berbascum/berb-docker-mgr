# Upstream-Name: berb-droidian-kernel-build-docker-mgr
# Source: https://gitlab.com/droidian-berb/berb-droidian-kernel-build-docker-mgr
  ## Script that manages a custom docker container with Droidian build environment

# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
# All rights reserved.
#
# BSD 3-Clause License


fn_main_vars() {
    target_arch="arm64"
    host_arch="amd64"
    organization="droidian-berb"
    target_suite="trixie"
    host_suite="trixie"
    droidian_suite="trixie"
}
export -f fn_main_vars

fn_specific_vars() {
    vendor="xiaomi"
    codename="vayu"
    apiver="30"
}
export -f fn_specific_vars

