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

