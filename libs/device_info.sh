# Upstream-Name: berb-droidian-build-docker-mgr
# Source: https://github.com/droidian-berb/berb-droidian-build-docker-mgr
  ## Support vars for the main script

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

