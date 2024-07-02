#!/bin/bash -e

set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


PACK() 
{
    DIST_DIR=$1
    BUILD_DIR=$2
    OUT_DIR=$3
    ARCH=$(dpkg --print-architecture)
    source "${HERE}/../version.mk"
    PACKAGE_NAME="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}-amd64.exe"
    makensis -V4 -DAPP_VERSION=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH} ${DIST_DIR}/cellframe-node.nsis

    cp $DIST_DIR/*.exe $OUT_DIR/
}
