#!/bin/bash -e

set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


CMAKE=(cmake)
MAKE=(make)
POST_MAKE=()

echo "Linux target"
echo "CMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"
echo "POST_MAKE=${POST_MAKE[@]}"
