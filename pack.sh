#!/usr/bin/bash
set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


BUILD_ARCH="${1:-x86_64-linux-gnu}"
BUILD_TYPE="${2:-release}"
BUILD_DIR=${PWD}/build_${BUILD_ARCH}_${BUILD_TYPE}


echo "Pack [${BUILD_TYPE}] binaries for [$BUILD_ARCH] architecture from [${BUILD_DIR}]"



cd ${BUILD_DIR}

cpack .
