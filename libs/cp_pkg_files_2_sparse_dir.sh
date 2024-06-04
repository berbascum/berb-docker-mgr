#!/bin/bash

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
    cp -v libs/device_info.sh  sparse/usr/lib/${package_name}/
    cp -v libs/cp_pkg_files_2_sparse_dir.sh  sparse/usr/lib/${package_name}/
    cp -v libs/build-package-with-droidian-releng.sh  sparse/usr/lib/${package_name}/
}

## Main execution
fn_main_exec
