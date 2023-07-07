#!/bin/bash -e
#OSX BUILD 
#HAVE TO PROVIDE OSXCROSS_QT_ROOT variable
#HAVE TO PROVIDE OSXCROSS_QT_VERSION variable

set -e

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET=$(readlink "$SOURCE")
  if [[ $TARGET == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE=$TARGET
  else
    DIR=$( dirname "$SOURCE" )
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR')"
    SOURCE=$DIR/$TARGET # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
echo "SOURCE is '$SOURCE'"
RDIR=$( dirname "$SOURCE" )
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
HERE="$DIR"



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
