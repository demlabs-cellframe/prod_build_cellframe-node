#!/bin/bash



substitute_pkgname_postfix() {
	for variable in $(lsb_release -a 2>/dev/null | sed 's/\t//g' | sed 's/ //g' | sed 's/\:/\=/g'); do
		echo "variable is $variable"
		export $variable
	done
	sed -i "/ ${CMAKE_PATH}cpack_SYSTEM_TYPE/s/\".*\"/\"$DistributorID\"/" CMakeLists.txt
	sed -i "/ ${CMAKE_PATH}cpack_SYSTEM_VERSION/s/\".*\"/\"$Release\"/" CMakeLists.txt
	sed -i "/ ${CMAKE_PATH}cpack_SYSTEM_CODENAME/s/\".*\"/\"$Codename\"/" CMakeLists.txt
	export -n "DistributorID"
	export -n "Release"
	export -n "Codename"
	export -n "Description"
}

repack() {

DEBNAME=$1
DISTR_CODENAME="$Codename"
echo "Renaming controlde on $DEBNAME"
mkdir tmp && cd tmp

#Просматриваем архив и ищем строку с control.tar
#Результат заносим в переменную
CONTROL=$(ar t ../${DEBNAME} | grep control.tar)

ar x ../$DEBNAME $CONTROL
tar xf $CONTROL
VERSION=$(cat control | grep Version | cut -d ':' -f2)
echo "Version is $VERSION"
sed -i "s/$VERSION/${VERSION}-${DISTR_CODENAME}/" control
rm $CONTROL && tar zcf $CONTROL *
ar r ../$DEBNAME $CONTROL
cd ..
rm -rf tmp

}

pwd
error=0
mkdir -p packages

echo "Build for $ARCH_VERSIONS architectures"
substitute_pkgname_postfix && mkdir -p build && cd build && ${CMAKE_PATH}cmake ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * \
&& ${CMAKE_PATH}cmake -DCMAKE_BUILD_TYPE=Debug ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * || error=$?

echo $error
if [[ $(echo $ARCH_VERSIONS | grep arm64) != "" && $error == 0 ]]; then
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_ARM64
	${CMAKE_PATH}cmake -DCMAKE_C_COMPILER=$ARM64_C_COMPILER -DCMAKE_CXX_COMPLIER=$ARM64_CXX_COMPILER -DCMAKE_TARGET_ARCH="arm64" .. && make -j$(nproc) && \
	${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * && \
	${CMAKE_PATH}cmake -DCMAKE_BUILD_TYPE=Debug ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * || error=$?
	unset LD_LIBRARY_PATH
fi

if [[ $(echo $ARCH_VERSIONS | grep armhf) != "" && $error == 0 ]]; then
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_ARMHF
	${CMAKE_PATH}cmake -DCMAKE_C_COMPILER=$ARMHF_C_COMPILER -DCMAKE_CXX_COMPLIER=$ARMHF_CXX_COMPILER -DCMAKE_TARGET_ARCH="armhf" .. && make -j$(nproc) && \
	${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * && \
	${CMAKE_PATH}cmake -DCMAKE_BUILD_TYPE=Debug ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * || error=$?
	unset LD_LIBRARY_PATH
fi

if [[ $(echo $BUILD_TYPE | grep PGSQL) != "" && $error == 0 ]]; then
	sed -ibak 's/#set(BUILD_WITH_GDB_DRIVER_PGSQL ON)/set(BUILD_WITH_GDB_DRIVER_PGSQL ON)/' ../CMakeLists.txt || error=$?
	${CMAKE_PATH}cmake ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * \
	&& ${CMAKE_PATH}cmake -DCMAKE_BUILD_TYPE=Debug ../ && make -j$(nproc) && ${CMAKE_PATH}cpack && repack *.deb && mv -v *.deb ../packages/ && rm -r * || error=$?
fi

cd .. && rm -r build
[ -e CMakeLists.txtbak ] && mv -f CMakeLists.txtbak CMakeLists.txt

exit $error


### touch /etc/apt/sources.list.d/demlabs.list deb https://debian.pub.demlabs.net/ bionic main universe multiverse

### wget https://debian.pub.demlabs.net/debian.pub.demlabs.net.gpg
### apt-key add demlabskey.asc




