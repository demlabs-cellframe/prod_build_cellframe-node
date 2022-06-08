#!/usr/bin/bash
set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi

#build architecture 
#- aarch64-apple-darvin
#- aarch64-linux-gnu
#- armv7-linux-gnu
#- x86_64-apple-darvin  
#- x86_64-windows-mingw
#- x86_64-linux-gnu
#- i686-linux-gnu
#- aarch64-android
#- armv7-android
#- armv6-android

# freebsb? openbsd? netbsd? openwrt
# ios (ipad/iphone) aarch64-ios-darwin

BUILD_ARCH="${1:-x86_64-linux-gnu}"
BUILD_TYPE="${2:-release}"

echo "Build [${BUILD_TYPE}] binaries for [$BUILD_ARCH] architecture"

cd ${PWD}

mkdir -p ./build
cd ./build
cmake ../ 
make -j$(nproc)
