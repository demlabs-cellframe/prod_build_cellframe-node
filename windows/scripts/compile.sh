DESTDIR=$1
wd=$2
export PATH=$WINDOWS_TOOLCHAIN_PATH/usr/bin:$PATH

cd $wd && mkdir build && cd build && \
x86_64-w64-mingw32.static-cmake .. && make -j$(nproc) || echo "$PATH error $?" && exit $?

