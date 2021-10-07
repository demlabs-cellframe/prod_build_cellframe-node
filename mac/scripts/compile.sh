#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

export _CMAKE_OSX_SYSROOT_PATH="MacOS"

mkdir build
cd build && 
 "$CROSS_COMPILE"cmake .. \
&& make -j$(nproc) || exit $?

unset _CMAKE_OSX_SYSROOT_PATH 
exit 0
