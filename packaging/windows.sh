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
    PACKAGE_NAME="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-amd64.exe"
    NSIS_ROOT="${DIST_DIR}/opt/cellframe-node"
    if [ ! -f "${NSIS_ROOT}/cellframe-node.nsis" ]; then
        # Fallback to dist root (some builds install NSIS assets to /dist directly)
        NSIS_ROOT="${DIST_DIR}"
    fi
    if [ ! -f "${NSIS_ROOT}/cellframe-node.nsis" ]; then
        echo "NSIS script not found in ${DIST_DIR} or ${DIST_DIR}/opt/cellframe-node"
        exit 1
    fi
    NSIS_PATCH=${VERSION_PATCH}
    if ! [[ "${NSIS_PATCH}" =~ ^[0-9]+$ ]]; then
        NSIS_PATCH=0
    fi
    NSIS_VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${NSIS_PATCH}.0"
    # Ensure NSIS script and assets are next to it so relative paths resolve correctly (prefer sources)
    if [ -n "${SOURCES}" ] && [ -f "${SOURCES}/os/windows/cellframe-node.nsis" ]; then
        cp -f "${SOURCES}/os/windows/cellframe-node.nsis" "${DIST_DIR}/"
    fi
    if [ -n "${SOURCES}" ] && [ -f "${SOURCES}/resources/cellframe.ico" ]; then
        cp -f "${SOURCES}/resources/cellframe.ico" "${DIST_DIR}/"
    fi
    if [ -n "${SOURCES}" ] && [ -f "${SOURCES}/resources/cellframe.bmp" ]; then
        cp -f "${SOURCES}/resources/cellframe.bmp" "${DIST_DIR}/"
    fi

    # Ensure NSIS script and assets are next to it so relative paths resolve correctly
    if [ "${NSIS_ROOT}" != "${DIST_DIR}" ]; then
        cp "${NSIS_ROOT}/cellframe-node.nsis" "${DIST_DIR}/"
        cp "${NSIS_ROOT}/cellframe.ico" "${DIST_DIR}/"
        cp "${NSIS_ROOT}/cellframe.bmp" "${DIST_DIR}/"
    fi
    makensis -V4 -DAPP_VERSION_VISUAL=${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH} -DAPP_VERSION=${NSIS_VERSION} "${DIST_DIR}/cellframe-node.nsis"

    cp $DIST_DIR/*.exe $OUT_DIR/
}
