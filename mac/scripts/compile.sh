#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

mkdir build
cd build && СС="$CROSS_COMPILE"gcc "$CROSS_COMPILE"cmake .. && make -j$(nproc) || echo "error $?" && exit $?
