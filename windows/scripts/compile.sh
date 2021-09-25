#!/bin/bash

DESTDIR=$1
wd=$2

echo "[INF] Building cellframe-node"
cd $wd 

. prod_build/general/pre-build.sh

export_variables "./prod_build/windows/conf/*"


IFS=" "
for lib in $LIBS; do
	new_lib=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
	echo "changing $lib to $new_lib"
	sed -i "s/$lib/$new_lib/g" CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/dap-sdk/net/server/enc_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/dap-sdk/net/server/http_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/dap-sdk/net/server/enc_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/dap-sdk/net/server/http_server/CMakeLists.txt
done



mkdir build && cd build && \
x86_64-w64-mingw32.static-cmake .. && make -j$(nproc) && \
cp -f cellframe-node*.exe $DESTDIR || echo "$PATH error $?" && exit $?

