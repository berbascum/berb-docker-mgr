#!/bin/bash

extra_packages=(
    "apt-utils"
    "vim"
    "htop"
    "git"
    "wget"
    "rsync"
    "less"
    "bash-completion" 
    "net-tools"
    "build-essential"
    "devscripts"
    "lintian"
    "fakeroot"
    "debhelper"
    "dh-make"
    "equivs"
    "dpkg-dev"
)

extra_packages_string=$(printf "%s " "${extra_packages[@]}")

sudo docker build -f Dockerfile_arm64 --build-arg EXTRA_PACKAGES="$extra_packages_string" -t berb-build-env:trixie-arm64 .

