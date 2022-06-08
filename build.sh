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

BUILD_ARCH=$1

echo "Build for $BUILD_ARCH architecture"

cd ${PWD}
echo "Build release"
mkdir -p build_release
cd ./build_release	
cmake ../ 
make

сd ${PWD}
echo "Build debug"
mkdir -p ./build_debug
cd ../build_debug
cmake ../ -DCMAKE_BUILD_TYPE=Debug
make