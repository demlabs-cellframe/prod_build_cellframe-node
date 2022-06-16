#!/bin/bash
set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi

#build architecture 
#- amd64-darvin
#- amd64-linux
#- armhf-linux
#- armv7-linux

# freebsb? openbsd? netbsd? openwrt
# ios (ipad/iphone) aarch64-ios-darwin

BUILD_ARCH="${1:-amd64-linux}"
BUILD_TYPE="${2:-release}"
BUILD_DIR=${PWD}/build_${BUILD_ARCH}_${BUILD_TYPE}

echo "Build [${BUILD_TYPE}] binaries for [$BUILD_ARCH] architecture in [${BUILD_DIR}] on $(nproc) threads."

#make build directory and cd in 
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

#define DEBUG for build if neccessary
if [ "${BUILD_TYPE}" = "debug" ]; then
    cmake ../ -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TARGET_ARCH=$BUILD_ARCH
else
    cmake ../ -DCMAKE_TARGET_ARCH=$BUILD_ARCH
fi

#call make to do the build process
make -j"$(nproc)"
