#!/bin/bash -e

set -e

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET=$(readlink "$SOURCE")
  if [[ $TARGET == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE=$TARGET
  else
    DIR=$( dirname "$SOURCE" )
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR')"
    SOURCE=$DIR/$TARGET # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
echo "SOURCE is '$SOURCE'"
RDIR=$( dirname "$SOURCE" )
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
HERE="$DIR"


PKG_SIGN_POSSIBLE=1

if [ -z "$OSX_PKEY_INSTALLER" ]
then
	echo "No OSX_PKEY_INSTALLER provided. PKG will NOT be signed"
	PKG_SIGN_POSSIBLE=0
fi

if [ -z "$OSX_PKEY_APPLICATION" ]
then
	echo "No OSX_PKEY_APPLICATION provided. PKG will NOT be signed"
	PKG_SIGN_POSSIBLE=0
fi

if [ -z "$OSX_PKEY_INSTALLER_PASS" ]
then
	echo "No OSX_PKEY_INSTALLER_PASS provided. PKG will NOT be signed"
	PKG_SIGN_POSSIBLE=0
fi

if [ -z "$OSX_PKEY_APPLICATION_PASS" ]
then
	echo "No OSX_PKEY_APPLICATION_PASS provided. PKG will NOT be signed"
	PKG_SIGN_POSSIBLE=0
fi

if [ -z "$OSX_APPSTORE_CONNECT_KEY" ]
then
	echo "No OSX_APPSTORE_CONNECT_KEY provided. PKG will NOT be signed"
	PKG_SIGN_POSSIBLE=0
fi

# Removed old PACK_LINUX function - now using proper PACK_OSX function below



PACK_OSX() 
{
    DIST_DIR=$1
    BUILD_DIR=$2
    OUT_DIR=$3

	BRAND=CellframeNode

    #USED FOR PREPARATION OF UNIFIED BUNDLE
    #all binaries and some structure files are threre
    PACKAGE_DIR=${DIST_DIR}/osxpackaging

    #USED FOR PROCESSING OF PREPARED BUNDLE: BOM CREATION, ETC
    OSX_PKG_DIR=${DIST_DIR}/pkg

	BRAND_OSX_BUNDLE_DIR=${DIST_DIR}/Applications/CellframeNode.app

    #prepare correct packaging structure
    mkdir -p ${PACKAGE_DIR}
    mkdir -p ${OSX_PKG_DIR}

    echo "Creating unified package structure in [$BRAND_OSX_BUNDLE_DIR]"

    #copy pkginstall
	cp  ${HERE}/../../os/macos/PKGINSTALL/* ${PACKAGE_DIR}

	echo "Do packaging magic in [$PACKAGE_DIR]"
	
	#get version info
	source "${HERE}/../../version.mk"
    PACKAGE_NAME="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-amd64.pkg"
	PACKAGE_NAME_SIGNED="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-amd64-signed.pkg"
    echo "Building package [$PACKAGE_NAME]"

	#prepare payload structure - create Applications directory in payload
	PAYLOAD_BUILD=${PACKAGE_DIR}/payload_build
	SCRIPTS_BUILD=${PACKAGE_DIR}/scripts_build

	mkdir -p ${PAYLOAD_BUILD}/Applications
	mkdir -p ${SCRIPTS_BUILD}

	# Copy the app bundle to Applications directory in payload
	cp -r ${BRAND_OSX_BUNDLE_DIR} ${PAYLOAD_BUILD}/Applications/

	# Copy install scripts
	cp ${PACKAGE_DIR}/preinstall ${SCRIPTS_BUILD}
	cp ${PACKAGE_DIR}/postinstall ${SCRIPTS_BUILD}

	# Code signing if certificates are available
	if [ "$PKG_SIGN_POSSIBLE" -eq "1" ]; then
		echo "Code-signing binaries"
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} \
		${PAYLOAD_BUILD}/Applications/CellframeNode.app/Contents/MacOS/cellframe-node
		
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} \
		${PAYLOAD_BUILD}/Applications/CellframeNode.app/Contents/MacOS/cellframe-node-cli
		
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} \
		${PAYLOAD_BUILD}/Applications/CellframeNode.app/Contents/MacOS/cellframe-node-tool
		
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} \
		${PAYLOAD_BUILD}/Applications/CellframeNode.app/Contents/MacOS/cellframe-node-config
		
		# Sign the entire app bundle
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} \
		${PAYLOAD_BUILD}/Applications/CellframeNode.app
	fi
	
	# Use pkgbuild to create the package
	cd ${OUT_DIR}
	pkgbuild --root ${PAYLOAD_BUILD} \
			 --identifier "com.demlabs.CellframeNode" \
			 --version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}" \
			 --install-location "/" \
			 --scripts ${SCRIPTS_BUILD} \
			 ${PACKAGE_NAME}
			 
	# Sign the package if certificates are available
	if [ "$PKG_SIGN_POSSIBLE" -eq "1" ]; then
		echo "Signing package $PACKAGE_NAME to $PACKAGE_NAME_SIGNED"
		
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} \
		${PACKAGE_NAME} ${PACKAGE_NAME_SIGNED}
		
		echo "Notarizing package"
		rcodesign notary-submit --api-key-path ${OSX_APPSTORE_CONNECT_KEY} ${PACKAGE_NAME_SIGNED} --staple
	fi
}

NAME_OUT="$(uname -s)"
case "${NAME_OUT}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    MSYS_NT*)   MACHINE=Git;;
    *)          MACHINE="UNKNOWN:${NAME_OUT}"
esac

PACK() 
{
	# Always use PACK_OSX for macOS builds
	PACK_OSX $@
}
