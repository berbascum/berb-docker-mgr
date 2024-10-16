#!/bin/bash

IMG_DISTRO="debian"
IMG_SUITE="trixie"
IMG_SUBSUITE="-slim" ## Empty to none
IMG_ARCH="arm64"
IMG_NAME="berb-debian-base"

extra_packages=(
    "vim"
    "htop"
    "git"
    "wget"
    "rsync"
    "less"
    "bash-completion" 
    "net-tools"
)

extra_packages_string=$(printf "%s " "${extra_packages[@]}")

docker build -f Dockerfile_${IMG_DISTRO}_${IMG_SUITE}${IMG_SUBSUITE}_${IMG_ARCH} --build-arg EXTRA_PACKAGES="$extra_packages_string" -t ${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH} .
