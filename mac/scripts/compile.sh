#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

mkdir build
cd build && "$CROSS_COMPILE"cmake  -D CMAKE_C_COMPILER="$CROSS_COMPILE"gcc .. && make -j$(nproc) || exit $?
