#!/bin/bash

echo "Deploying to $PACKAGE_PATH"
echo $wd

CELLFRAME_REPO_KEY="~/.ssh/demlabs_publish"
PUB_REPO_PORT=34768
PVT_REPO_PORT=22
CELLFRAME_PUB_REPO_CREDS="admin@debian.pub.demlabs.net"
CELLFRAME_PUB_CREDS="admin@pub.cellframe.net"
CELLFRAME_PUB_PATH="~/web/pub.cellframe.net/public_html/linux"
CELLFRAME_PVT_CREDS="admin@pvt.demlabs.net"
CELLFRAME_PVT_PATH="~/web/public/cellframe-node"
pwd

cd packages
PKGFILES=$(ls . | grep .deb)

[[ -v CI_COMMIT_REF_NAME ]] && [[ $CI_COMMIT_REF_NAME != "master" ]] && SUBDIR="${CI_COMMIT_REF_NAME}" || SUBDIR=""

#echo "We have $DISTR_CODENAME there"
#echo "On path $REPO_DIR_SRC we have debian files."
for pkgfile in $PKGFILES; do
	if [[ $(echo $pkgfile | grep "pgsql") == "" ]]; then
		CELLFRAME_FILESERVER_CREDS=$CELLFRAME_PUB_CREDS
		CELLFRAME_FILESERVER_PATH=$CELLFRAME_PUB_PATH
		CELLFRAME_REPO_CREDS=$CELLFRAME_PUB_REPO_CREDS
		REPO_PORT=$PUB_REPO_PORT
	else
		CELLFRAME_FILESERVER_CREDS=$CELLFRAME_PVT_CREDS
		CELLFRAME_FILESERVER_PATH=$CELLFRAME_PVT_PATH
		CELLFRAME_REPO_CREDS=$CELLFRAME_PVT_CREDS
		REPO_PORT=$PVT_REPO_PORT
	fi
	pkgname=$(echo $pkgfile | sed 's/.deb$//')
	pkgname_public=$(echo $pkgname | cut -d '-' -f1-4,7,8) #cutting away Debian-9.12
	pkgname_weblink="$(echo $pkgname | cut -d '-' -f2,7 )-latest" #leaving only necessary entries
	echo "Package name for public is $pkgname_public"
	mv $pkgfile $wd/$PACKAGE_PATH/$pkgname.deb || { echo "[ERR] Something went wrong in publishing the package. Now aborting."; exit -4; }
	CODENAME=$(echo $pkgname | rev | cut -d '-' -f1 | rev)
	cp -r ../prod_build/general/essentials/weblink-latest ../prod_build/general/essentials/$pkgname_weblink
	sed -i "/document/s/cellframe.*deb/$pkgname_public.deb/" ../prod_build/general/essentials/$pkgname_weblink/index.html
	echo "REF_NAME is $CI_COMMIT_REF_NAME"
	ssh -i $CELLFRAME_REPO_KEY "$CELLFRAME_FILESERVER_CREDS" "mkdir -p $CELLFRAME_FILESERVER_PATH/$SUBDIR"
	echo "added $pkgname.deb how $pkgname_public.deb"
	scp -i $CELLFRAME_REPO_KEY $wd/$PACKAGE_PATH/$pkgname.deb "$CELLFRAME_FILESERVER_CREDS:$CELLFRAME_FILESERVER_PATH/$SUBDIR/$pkgname_public.deb"
	if [[ $CI_COMMIT_REF_NAME == "master" && $(echo $pkgname | grep "dbg") == "" ]]; then
		scp -r -i $CELLFRAME_REPO_KEY ../prod_build/general/essentials/$pkgname_weblink "$CELLFRAME_FILESERVER_CREDS:$CELLFRAME_FILESERVER_PATH/$SUBDIR/"
		scp -P $REPO_PORT -i $CELLFRAME_REPO_KEY $wd/$PACKAGE_PATH/$pkgname.deb "$CELLFRAME_REPO_CREDS:~/aptly/repo_update/$pkgname_public.deb"
		ssh -p $REPO_PORT -i $CELLFRAME_REPO_KEY "$CELLFRAME_REPO_CREDS" -- "~/aptly/repo_update.sh"
	fi

	rm -r ../prod_build/general/essentials/$pkgname_weblink
done

cd ..
exit 0
#symlink name-actual to the latest version.
#build/deb/versions - for all files
#build/deb/${PROJECT}-latest - for symlinks.
