#!/usr/bin/bash
set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi

ls ${PWD}
cd ${BUILD_DIR}
