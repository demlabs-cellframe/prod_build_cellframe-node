#!/bin/bash

wd=$1

echo "[INF] Building cellframe-node"
cd $wd 

mkdir build
cd build && "$CROSS_COMPILE"cmake .. \
 -DCMAKE_C_COMPILER="$CROSS_COMPILE"gcc \
 -DPYTHON_INCLUDE_DIR=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")  \
 -DPYTHON_LIBRARY=$(python -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR'))") \
&& make -j$(nproc) || exit $?
