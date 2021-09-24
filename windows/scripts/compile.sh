DESTDIR=$1
wd=$2

cd $wd && mkdir build && cd build && \
x86_64-w64-mingw32.static-cmake .. && make && make install DESTDIR=$DESTDIR || echo "error $?" && exit $?
