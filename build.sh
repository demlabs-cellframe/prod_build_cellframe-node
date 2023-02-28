#!/bin/bash
set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi

export SOURCES=${HERE}/../

#validate input params
. ${HERE}/validate.sh

Help()
{
   echo "cellframe-node build"
   echo "Usage: build.sh [--target ${TARGETS}] [${BUILD_TYPES}]  [OPTIONS]"
   echo "options:   -DWHATEVER=ANYTHING will be passed to cmake as defines"
   echo
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      Help
      shift # past argument
      shift # past value
      ;;
    -t|--target)
      TARGET="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

BUILD_TYPE="${1:-release}"
BUILD_OPTIONS="${@:2}"

BUILD_TARGET="${TARGET:-linux}"

BUILD_DIR=${PWD}/build_${BUILD_TARGET}_${BUILD_TYPE}

VALIDATE_TARGET $TARGET
VALIDATE_BUILD_TYPE $BUILD_TYPE

#append qmake debug\release qmake options for this
if [ "${BUILD_TYPE}" = "debug" ]; then
    BUILD_OPTIONS[${#BUILD_OPTIONS[@]}]="-DCMAKE_BUILD_TYPE=Debug"
else
    if [ "${BUILD_TYPE}" = "rwd" ]; then
      BUILD_OPTIONS[${#BUILD_OPTIONS[@]}]="-DCMAKE_BUILD_TYPE=RelWithDebInfo"
    else
      BUILD_OPTIONS[${#BUILD_OPTIONS[@]}]="-DCMAKE_BUILD_TYPE=Release"
    fi
fi

. ${HERE}/targets/${BUILD_TARGET}.sh

#all base logic from here
mkdir -p ${BUILD_DIR}/build
mkdir -p ${BUILD_DIR}/dist

echo "Build [${BUILD_TYPE}] binaries for [$BUILD_TARGET] in [${BUILD_DIR}] on $(nproc) threads"
echo "with options: [${BUILD_OPTIONS[@]}]"

cd ${BUILD_DIR}/build

#debug out
echo "$CMAKE ${BUILD_OPTIONS[@]}"
export INSTALL_ROOT=${BUILD_DIR}/dist
"${CMAKE[@]}" ${HERE}/../ -DCREATE_DEFAULT_CONFIG=OFF ${BUILD_OPTIONS[@]}  
"${MAKE[@]}" -j$(nproc)
"${MAKE[@]}" install DESTDIR=${INSTALL_ROOT}
