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
)

extra_packages_string=$(printf "%s " "${extra_packages[@]}")

docker build --platform=linux/arm64 --build-arg EXTRA_PACKAGES="$extra_packages_string" -t berb-linux-env:trixie-amd64 .

