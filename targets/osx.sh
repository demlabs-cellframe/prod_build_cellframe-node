#!/bin/bash -e
#OSX BUILD 
#HAVE TO PROVIDE OSXCROSS_QT_ROOT variable
#HAVE TO PROVIDE OSXCROSS_QT_VERSION variable

set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


if [ -z "$OSXCROSS_QT_ROOT" ]
then
      echo "Please, export OSXCROSS_QT_ROOT variable, pointing to Qt-builds locations for osxcross environment"
      exit 255
fi


if [ -z "$OSXCROSS_QT_VERSION" ]
then
      echo "Please, export OSXCROSS_QT_VERSION variable, scpecifying Qt-version in OSXCROSS_QT_ROOT directory."
      exit 255
fi

echo "Using QT ${OSXCROSS_QT_VERSION} from ${OSXCROSS_QT_ROOT}/${OSXCROSS_QT_VERSION}"

[ ! -d ${OSXCROSS_QT_ROOT}/${OSXCROSS_QT_VERSION} ] && { echo "No QT ${OSXCROSS_QT_VERSION} found in ${OSXCROSS_QT_ROOT}" && exit 255; }

#define QMAKE & MAKE commands for build.sh script
export OSXCROSS_VERSION=1.4
export OSXCROSS_OSX_VERSION_MIN=10.9
export OSXCROSS_TARGET=darwin20.4
export OSXCROSS_BASE_DIR=/osxcross/build/..
export OSXCROSS_SDK=/opt/osxcross/bin/../SDK/MacOSX11.3.sdk
export OSXCROSS_SDK_DIR=/opt/osxcross/bin/../SDK/MacOSX11.3.sdk/..
export OSXCROSS_SDK_VERSION=11.3
export OSXCROSS_TARBALL_DIR=/osxcross/build/../tarballs
export OSXCROSS_PATCH_DIR=/osxcross/build/../patches
export OSXCROSS_TARGET_DIR=/opt/osxcross/bin/..
export OSXCROSS_DIR_SDK_TOOLS=/opt/osxcross/bin/../SDK/MacOSX11.3.sdk/../tools
export OSXCROSS_BUILD_DIR=/osxcross/build
export OSXCROSS_CCTOOLS_PATH=/opt/osxcross/bin
export OSXCROSS_LIBLTO_PATH=/usr/lib/llvm-11/lib
export OSXCROSS_LINKER_VERSION=609
export PATH=/opt/osxcross//bin:/opt/osxcross//bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/osxcross/bin

export CC=${OSXCROSS_ROOT}/bin/x86_64-apple-darwin20.4-clang
export CXX=${OSXCROSS_ROOT}bin/x86_64-apple-darwin20.4-clang++

CMAKE=(cmake)

#everything else can be done by default make
MAKE=(make)

echo "OSXcross target"
echo "QMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"