#!/bin/bash -e

set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


FILL_VERSION()
{
    source "${HERE}/../version.mk"

    VERSION_UPDATE="s|VERSION_MAJOR|${VERSION_MAJOR}|g"
    BUILD_UPDATE="s|VERSION_MINOR|${VERSION_MINOR}|g"
    MAJOR_UPDATE="s|VERSION_PATCH|${VERSION_PATCH}|g"

    for TEMPLATE in "$@"; do
        sed \
            -e "${VERSION_UPDATE}" \
            -e "${BUILD_UPDATE}" \
            -e "${MAJOR_UPDATE}" \
            -i "${TEMPLATE}"
    done
}

PACK() 
{
    
    DIST_DIR=$1
    BUILD_DIR=$2
    OUT_DIR=$3

    cd $BUILD_DIR
    cpack ./
    cp *.deb ${OUT_DIR}
}