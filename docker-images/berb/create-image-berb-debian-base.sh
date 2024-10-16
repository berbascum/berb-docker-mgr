#!/bin/bash

IMG_DISTRO="debian"
IMG_SUITE="trixie"
IMG_SUBSUITE="-slim" ## Empty to none
IMG_ARCH="arm64"
IMG_NAME="berb-debian-base"
REMOTE_USER="berbascum"
REMOTE_PREFIX="ghcr.io/${REMOTE_USER}"

## Extra packages
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

## Image creation
docker build -f Dockerfile_${IMG_DISTRO}_${IMG_SUITE}${IMG_SUBSUITE}_${IMG_ARCH} --build-arg EXTRA_PACKAGES="$extra_packages_string" -t ${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH} .

## Tag as remote
echo ""
echo "Creating remote tag: ${REMOTE_PREFIX}/${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH}"

docker tag \
    ${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH} \
    ${REMOTE_PREFIX}/${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH}

## Push the image
echo ""
echo "Pushing the image: ${REMOTE_PREFIX}/${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH}"
echo""
read -p "Continue? [ y | any ]: " answer
[ "${answer}" != "y" ] && echo "Aborted" && exit
docker push \
    ${REMOTE_PREFIX}/${IMG_NAME}:${IMG_SUITE}${IMG_SUBSUITE}-${IMG_ARCH}
