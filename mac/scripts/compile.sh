#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

mkdir build
cd build && "$CROSS_COMPILE"cmake .. && make -j$(nproc) || echo "error $?" && exit $?
