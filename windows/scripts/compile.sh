DESTDIR=$1
wd=$2

cd $wd 

. prod_build/general/pre-build.sh

export_variables "prod_build/windows/conf/*"

IFS=" "
for lib in $LIBS; do
	new_lib=${lib,,}
	sed -i "s/$lib/$new_lib/g" CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/dap-sdk/net/server/enc_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" cellframe-sdk/dap-sdk/net/server/http_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/dap-sdk/net/server/enc_server/CMakeLists.txt
	sed -i "s/$lib/$new_lib/g" python-cellframe/cellframe-sdk/dap-sdk/net/server/http_server/CMakeLists.txt
done


mkdir build && cd build && \
x86_64-w64-mingw32.static-cmake .. && make -j$(nproc) || echo "$PATH error $?" && exit $?

