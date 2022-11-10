#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

mkdir build
cd build && 
 "$CROSS_COMPILE"cmake .. -DMACOS_ARCH="x86_64" \
&& make -j$(nproc) || exit $?

exit 0
