#!/bin/bash

platform=$1
echo "workdir is $(pwd)"
. prod_build/general/pre-build.sh
export_variables "./prod_build/general/conf/*"

[ -e prod_build/$platform/scripts/pre-build.sh ] && prod_build/$platform/scripts/pre-build.sh || exit $? #For actions before build not in chroot and in chroot (version update, install missing dependencies(under schroot))
prod_build/$platform/scripts/build.sh $PKG_TYPE || { errcode=$? && unexport_variables "./prod_build/$platform/conf/*"; exit $errcode; }
echo "workdir before postinstall is $(pwd)"
#[ -e prod_build/$platform/scripts/post-build.sh ] && prod_build/$platform/scripts/post-build.sh errcode=$? #For post-build actions not in chroot (global publish)
unexport_variables "./prod_build/$platform/conf/*"

cd $wd

exit $errcode
