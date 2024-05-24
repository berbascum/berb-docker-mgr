#!/bin/bash

## Berbascum's script to install a specific python prebuilt on the kernel source

## Install a python prebuilt with zlib support

echo; echo "Checking for python with zlib support..."
INI_DIR=$(pwd)
PYTHON_BASE_VER="2.7"
PYTHON_SUB_VER="2.7.5"
PYTHON_PREFIX="/buildd/sources/${DISTRO}/python"
HOST_ARCH="i386"
SUITE="trixie"

## The exports need to be executed by the kernel-snippet.mk on Droidian builds
export PATH="${PYTHON_PREFIX}/${PYTHON_SUB_VER}/bin:${PATH}"
[ -n "${LD_LIBRARY_PATH}" ] && other_path=":" || other_path=""
export LD_LIBRARY_PATH="${PYTHON_PREFIX}/${PYTHON_SUB_VER}/lib${other_path}${LD_LIBRARY_PATH}"
#export PYTHONPATH="/opt/android/prebuilts/python/${PYTHON_SUB_VER}/lib/python${PYTHON_BASE_VER}"


if [ ! -d "${PYTHON_PREFIX}/${PYTHON_SUB_VER}" ]; then
    echo; echo "The custom python prebuilt with zlib support does not found. Installing..."
    ## Create python dest path if not exist
    mkdir -v -p "${PYTHON_PREFIX}"
    ## Get the prebuil tar.gz file
    PY_PREBUILT_BASE_URL="https://github.com/berbascum/berb-python-prebuilts/raw/main/python${PYTHON_SUB_VER}"
    PY_PREBUILT_TAR="python${PYTHON_SUB_VER}-${HOST_ARCH}-${SUITE}-prebuilt-zlib_static_prefix-droidian-krnl.tar.gz"
    cd ${PYTHON_PREFIX}
    wget "${PY_PREBUILT_BASE_URL}/${PY_PREBUILT_TAR}"
    ## Extract the downloaded python prebuilt
    tar zxvf "${PY_PREBUILT_TAR}"
    cd ${PYTHON_SUB_VER}/bin
    rm python python2 python-config python2-config
    mv python2.7 python275b
    rm -v "${PY_PREBUILT_TAR}"
    cd ${INI_DIR}
else
    echo; echo "extra python prebuild detected."
fi
