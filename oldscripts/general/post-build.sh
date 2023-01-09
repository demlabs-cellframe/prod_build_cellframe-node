echo "workdir before postinstall is $(pwd)"

platform=$1
errstring=""
errcode=0

. prod_build/general/pre-build.sh
for conffile in $(find "./prod_build/$platform/conf" | grep conf/ | grep -v .bak); do
	export_variables $conffile
	echo "export variables from $conffile"
done
export_variables "prod_build/general/conf/*"

[[ -e prod_build/$platform/scripts/post-build.sh ]] && prod_build/$platform/scripts/post-build.sh $platform || { errcode=$? && errstring="$errstring ${platform}_postbuild errcode $errcode"; } #For post-build actions not in chroot (global publish)
[[ $errstring != "" ]] && echo "$brand done with errors:" && echo "$errstring" >> ~/prod_log && errstring="" && errcode=5 ## General failure error

unexport_variables $(find "./prod_build/$platform/conf" -maxdepth 1 -type f)

exit  $errcode
