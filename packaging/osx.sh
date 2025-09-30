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

PACK_LINUX() 
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

    #copy base application bundle
    #path to it in BRAND_OSX_BUNDLE_DIR
    #cp -r ${DIST_DIR}/Applications/CellframeNode.app ${PACKAGE_DIR}/CellframeNode.app

    #copy pkginstall
	cp  ${HERE}/../../os/macos/PKGINSTALL/* ${PACKAGE_DIR}

	echo "Do packaging magic in [$PACKAGE_DIR]"
	cd $wd
	
	#get version info
	source "${HERE}/../../version.mk"
    PACKAGE_NAME="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-universal.pkg"
	PACKAGE_NAME_SIGNED="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-universal-signed.pkg"
    echo "Building package [$PACKAGE_NAME]"

	#prepare
	PAYLOAD_BUILD=${PACKAGE_DIR}/payload_build
	SCRIPTS_BUILD=${PACKAGE_DIR}/scripts_build

	mkdir -p ${PAYLOAD_BUILD}
	mkdir -p ${SCRIPTS_BUILD}

	cp ${HERE}/../../os/macos/Info.plist ${BRAND_OSX_BUNDLE_DIR}/Contents
	cp -r ${BRAND_OSX_BUNDLE_DIR} ${PAYLOAD_BUILD}

	if [ "$PKG_SIGN_POSSIBLE" -eq "1" ]; then
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} \
		${PAYLOAD_BUILD}/CellframeNode.app/Contents/MacOS/cellframe-node
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} \
		${PAYLOAD_BUILD}/CellframeNode.app/Contents/MacOS/cellframe-node-cli
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} \
		${PAYLOAD_BUILD}/CellframeNode.app/Contents/MacOS/cellframe-node-tool
		rcodesign sign --code-signature-flags runtime \
		--p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} \
		${PAYLOAD_BUILD}/CellframeNode.app/Contents/MacOS/cellframe-node-config
	fi

	cp ${PACKAGE_DIR}/preinstall ${SCRIPTS_BUILD}
	cp ${PACKAGE_DIR}/postinstall ${SCRIPTS_BUILD}

	#create .pkg struture to further xar coommand

	#code-sign binaries
	if [ "$PKG_SIGN_POSSIBLE" -eq "1" ]; then
		echo "Code-signig binaries"
		#add runtime flag to bypass notarization warnings about hardened runtime.
		rcodesign sign --code-signature-flags runtime --p12-file ${OSX_PKEY_APPLICATION} --p12-password ${OSX_PKEY_APPLICATION_PASS} ${PAYLOAD_BUILD}/${BRAND}.app
	fi

	# create bom file
	mkbom -u 0 -g 80 ${PAYLOAD_BUILD} ${OSX_PKG_DIR}/Bom

	# create Payload
	(cd ${PAYLOAD_BUILD} && find . | cpio -o --format odc --owner 0:80 | gzip -c) > ${OSX_PKG_DIR}/Payload
	# create Scripts
	(cd ${SCRIPTS_BUILD} && find . | cpio -o --format odc --owner 0:80 | gzip -c) > ${OSX_PKG_DIR}/Scripts

	#update PkgInfo
	cp ${PACKAGE_DIR}/PackageInfo ${OSX_PKG_DIR}

	numberOfFiles=$(find ${PAYLOAD_BUILD} | wc -l)
	installKBytes=$(du -k -s ${PAYLOAD_BUILD} | cut -d"$(echo -e '\t')" -f1)
	sed -i "s/numberOfFiles=\"[0-9]\+\"/numberOfFiles=\"$numberOfFiles\"/g" ${OSX_PKG_DIR}/PackageInfo
	sed -i "s/installKBytes=\"[0-9]\+\"/installKBytes=\"$installKBytes\"/" ${OSX_PKG_DIR}/PackageInfo
	sed -i "s/ version=\"[0-9]\+\"/ version=\"${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\"/" ${OSX_PKG_DIR}/PackageInfo
	cat ${OSX_PKG_DIR}/PackageInfo

	(cd $OSX_PKG_DIR && xar --compression none -cf ../../${PACKAGE_NAME} *)
	
	#check if we can sign pkg
	#for certificate preparation see this guide: https://users.wfu.edu/cottrell/productsign/productsign_linux.html
	#for other things see rcodesing help

	if [ "$PKG_SIGN_POSSIBLE" -eq "1" ]; then
		echo "Signig $PACKAGE_NAME to $PACKAGE_NAME_SIGNED"

		cd ${OUT_DIR}
		
		rcodesign sign --code-signature-flags runtime --p12-file ${OSX_PKEY_INSTALLER} --p12-password ${OSX_PKEY_INSTALLER_PASS} ${PACKAGE_NAME} ${PACKAGE_NAME_SIGNED}
		
		echo "Notarizing package (waiting for completion)..."
		# Use --wait flag to ensure notarization completes before stapling
		rcodesign notary-submit --api-key-path ${OSX_APPSTORE_CONNECT_KEY} ${PACKAGE_NAME_SIGNED} --wait --staple
		
		# Verify stapling
		echo "Verifying stapled ticket..."
		xcrun stapler validate ${PACKAGE_NAME_SIGNED} || echo "Warning: stapler validation failed"
		#rm ${PACKAGE_NAME}
	fi
}



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

    #copy base application bundle
    #path to it in BRAND_OSX_BUNDLE_DIR
    #cp -r ${DIST_DIR}/Applications/CellframeNode.app ${PACKAGE_DIR}/CellframeNode.app

    #copy pkginstall
	cp  ${HERE}/../../os/macos/PKGINSTALL/* ${PACKAGE_DIR}

	echo "Do packaging magic in [$PACKAGE_DIR]"
	
	
	#get version info
	source "${HERE}/../../version.mk"
    PACKAGE_NAME="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-universal.pkg"
    PACKAGE_NAME_SIGNED="cellframe-node-${VERSION_MAJOR}.${VERSION_MINOR}-${VERSION_PATCH}-universal-signed.pkg"
    PKG_PATH="${OUT_DIR}/${PACKAGE_NAME}"
    PKG_PATH_SIGNED="${OUT_DIR}/${PACKAGE_NAME_SIGNED}"
    echo "Building package [$PACKAGE_NAME]"

	#prepare
	PAYLOAD_BUILD=${PACKAGE_DIR}/payload_build
	SCRIPTS_BUILD=${PACKAGE_DIR}/scripts_build

	mkdir -p ${PAYLOAD_BUILD}
	mkdir -p ${SCRIPTS_BUILD}

	cp -r ${BRAND_OSX_BUNDLE_DIR} ${PAYLOAD_BUILD}

	cp ${PACKAGE_DIR}/preinstall ${SCRIPTS_BUILD}
	cp ${PACKAGE_DIR}/postinstall ${SCRIPTS_BUILD}

	# Native code signing on macOS host (codesign for app, productsign for pkg)
	# Expected env (provided by --sign config):
	#   OSX_SIGNING_IDENTITY or OSX_CODESIGN_IDENTITY  - Developer ID Application identity name
	#   OSX_INSTALLER_IDENTITY - Developer ID Installer identity name (optional, for productsign)
	# Optional:
	#   OSX_ENTITLEMENTS       - Path to entitlements.plist for app signing
	
	# Support both OSX_CODESIGN_IDENTITY and OSX_SIGNING_IDENTITY
	CODESIGN_ID="${OSX_CODESIGN_IDENTITY:-${OSX_SIGNING_IDENTITY}}"
	
	if [ -n "${CODESIGN_ID}" ]; then
		echo "Code-signing inner binaries with identity: ${CODESIGN_ID}"
		# Ensure executables are marked as executable before signing
		for b in cellframe-node-config cellframe-node-tool cellframe-node-cli cellframe-node; do
			if [ -f "${PAYLOAD_BUILD}/${BRAND}.app/Contents/MacOS/${b}" ]; then
				chmod +x "${PAYLOAD_BUILD}/${BRAND}.app/Contents/MacOS/${b}" || true
			fi
		done
		# Sign helpers first, then main binary
		for bin in cellframe-node-config cellframe-node-tool cellframe-node-cli cellframe-node; do
			if [ -f "${PAYLOAD_BUILD}/${BRAND}.app/Contents/MacOS/${bin}" ]; then
				if [ -n "${OSX_ENTITLEMENTS}" ] && [ -f "${OSX_ENTITLEMENTS}" ]; then
					codesign --force --options runtime --timestamp \
						--entitlements "${OSX_ENTITLEMENTS}" \
						--sign "${CODESIGN_ID}" \
						"${PAYLOAD_BUILD}/${BRAND}.app/Contents/MacOS/${bin}"
				else
					codesign --force --options runtime --timestamp \
						--sign "${CODESIGN_ID}" \
						"${PAYLOAD_BUILD}/${BRAND}.app/Contents/MacOS/${bin}"
				fi
			fi
		done

		echo "Code-signing app bundle: ${PAYLOAD_BUILD}/${BRAND}.app"
		if [ -n "${OSX_ENTITLEMENTS}" ] && [ -f "${OSX_ENTITLEMENTS}" ]; then
			codesign --force --options runtime --timestamp --deep \
				--entitlements "${OSX_ENTITLEMENTS}" \
				--sign "${CODESIGN_ID}" \
				"${PAYLOAD_BUILD}/${BRAND}.app"
		else
			codesign --force --options runtime --timestamp --deep \
				--sign "${CODESIGN_ID}" \
				"${PAYLOAD_BUILD}/${BRAND}.app"
		fi

		# Verify app signature before packaging
		codesign --verify --deep --strict --verbose=2 "${PAYLOAD_BUILD}/${BRAND}.app"
		spctl -a -vv "${PAYLOAD_BUILD}/${BRAND}.app" || true
	else
		echo "WARNING: OSX_SIGNING_IDENTITY / OSX_CODESIGN_IDENTITY is not set."
		echo "         App will NOT be signed on macOS host."
	fi

	
	pkgbuild --root ${PAYLOAD_BUILD} \
			 --component-plist ${PAYLOAD_BUILD}/../CellframeNode.plist \
			 --identifier "com.demlabs.CellframeNode" \
			 --version "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}" \
			 --install-location "/Applications" \
			 --scripts ${SCRIPTS_BUILD} \
			 "${PKG_PATH}" 

	# Sign the pkg if Installer identity provided
	if [ -n "${OSX_INSTALLER_IDENTITY}" ]; then
		echo "Signing pkg with Installer identity: ${OSX_INSTALLER_IDENTITY}"
		productsign --sign "${OSX_INSTALLER_IDENTITY}" "${PKG_PATH}" "${PKG_PATH_SIGNED}"
		# Verify pkg signature
		pkgutil --check-signature "${PKG_PATH_SIGNED}" || true
	else
		echo "OSX_INSTALLER_IDENTITY is not set. PKG will NOT be signed on macOS host."
	fi

	# Notarization using native macOS notarytool
	# Supports two methods:
	# 1. Direct credentials: OSX_NOTARY_KEY_PATH, OSX_NOTARY_KEY_ID, OSX_NOTARY_ISSUER_ID
	# 2. JSON config (like in PACK_LINUX): OSX_APPSTORE_CONNECT_KEY + OSX_APPSTORE_PRIVATE_KEY
	
	PKG_TO_NOTARIZE="${PKG_PATH_SIGNED}"
	if [ ! -f "${PKG_TO_NOTARIZE}" ]; then
		PKG_TO_NOTARIZE="${PKG_PATH}"
	fi
	
	if [ -n "${OSX_NOTARY_KEY_PATH}" ] && [ -n "${OSX_NOTARY_KEY_ID}" ] && [ -n "${OSX_NOTARY_ISSUER_ID}" ]; then
		# Method 1: Direct credentials
		echo "Submitting ${PKG_TO_NOTARIZE} for notarization via notarytool (direct credentials)"
		xcrun notarytool submit "${PKG_TO_NOTARIZE}" \
			--key "${OSX_NOTARY_KEY_PATH}" \
			--key-id "${OSX_NOTARY_KEY_ID}" \
			--issuer "${OSX_NOTARY_ISSUER_ID}" \
			--wait
		
		if [ -f "${PKG_PATH_SIGNED}" ]; then
			echo "Stapling notarization ticket..."
			xcrun stapler staple "${PKG_PATH_SIGNED}"
			echo "Verifying stapled ticket..."
			xcrun stapler validate "${PKG_PATH_SIGNED}"
		fi
	elif [ -n "${OSX_APPSTORE_CONNECT_KEY}" ] && [ -f "${OSX_APPSTORE_CONNECT_KEY}" ] && [ -n "${OSX_APPSTORE_PRIVATE_KEY}" ] && [ -f "${OSX_APPSTORE_PRIVATE_KEY}" ]; then
		# Method 2: Extract from JSON config (same as PACK_LINUX uses)
		echo "Extracting notarization credentials from ${OSX_APPSTORE_CONNECT_KEY}"
		
		# Parse JSON to extract key_id and issuer_id
		if command -v jq &> /dev/null; then
			NOTARY_KEY_ID=$(jq -r '.key_id' "${OSX_APPSTORE_CONNECT_KEY}")
			NOTARY_ISSUER_ID=$(jq -r '.issuer_id' "${OSX_APPSTORE_CONNECT_KEY}")
		elif command -v python3 &> /dev/null; then
			NOTARY_KEY_ID=$(python3 -c "import json; print(json.load(open('${OSX_APPSTORE_CONNECT_KEY}'))['key_id'])")
			NOTARY_ISSUER_ID=$(python3 -c "import json; print(json.load(open('${OSX_APPSTORE_CONNECT_KEY}'))['issuer_id'])")
		else
			echo "ERROR: Neither jq nor python3 available to parse JSON"
			echo "       Install jq or python3, or provide OSX_NOTARY_* variables directly"
			exit 1
		fi
		
		if [ -n "${NOTARY_KEY_ID}" ] && [ -n "${NOTARY_ISSUER_ID}" ]; then
			echo "Submitting ${PKG_TO_NOTARIZE} for notarization via notarytool (from JSON config)"
			echo "  Key ID: ${NOTARY_KEY_ID}"
			echo "  Issuer ID: ${NOTARY_ISSUER_ID}"
			
			xcrun notarytool submit "${PKG_TO_NOTARIZE}" \
				--key "${OSX_APPSTORE_PRIVATE_KEY}" \
				--key-id "${NOTARY_KEY_ID}" \
				--issuer "${NOTARY_ISSUER_ID}" \
				--wait
			
			if [ -f "${PKG_PATH_SIGNED}" ]; then
				echo "Stapling notarization ticket..."
				xcrun stapler staple "${PKG_PATH_SIGNED}"
				echo "Verifying stapled ticket..."
				xcrun stapler validate "${PKG_PATH_SIGNED}"
			fi
		else
			echo "ERROR: Failed to extract key_id or issuer_id from JSON"
			exit 1
		fi
	else
		echo "========================================="
		echo "WARNING: No notarization credentials provided!"
		echo "PKG will NOT be notarized and will be rejected by Gatekeeper."
		echo ""
		echo "Provide either:"
		echo "  Method 1: OSX_NOTARY_KEY_PATH, OSX_NOTARY_KEY_ID, OSX_NOTARY_ISSUER_ID"
		echo "  Method 2: OSX_APPSTORE_CONNECT_KEY (JSON) + OSX_APPSTORE_PRIVATE_KEY (.p8)"
		echo "========================================="
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
	if [ "$MACHINE" != "Mac" ]
	then
		PACK_LINUX $@
	else
		PACK_OSX $@
	fi
}

