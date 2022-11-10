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

$(${OSXCROSS_ROOT}/bin/osxcross-conf)


export OSXCROSS_HOST=x86_64-apple-darwin20.4
CMAKE=(cmake -DCMAKE_TOOLCHAIN_FILE=${OSXCROSS_ROOT}/toolchain.cmake)

##everything else can be done by default make
MAKE=(make)

echo "OSXcross target"
echo "CMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"