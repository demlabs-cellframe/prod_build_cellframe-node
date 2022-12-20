#!/bin/bash -e

set -e

if [ ${0:0:1} = "/" ]; then
	HERE=`dirname $0`
else
	CMD=`pwd`/$0
	HERE=`dirname ${CMD}`
fi


CMAKE=(cmake)
MAKE=(make -s)
POST_MAKE=(ar rc cellframe-node-lib.a $(find ./ -name "*.o"))

echo "Linux target"
echo "CMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"
echo "POST_MAKE=${POST_MAKE[@]}"
