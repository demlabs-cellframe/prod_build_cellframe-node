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

	# Use ditto instead of cp -r to properly preserve symlinks in frameworks
	ditto ${BRAND_OSX_BUNDLE_DIR} ${PAYLOAD_BUILD}/${BRAND}.app

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
	
	# Support both OSX_INSTALLER_IDENTITY and OSX_INSTALLER_SIGNING_IDENTITY
	OSX_INSTALLER_IDENTITY="${OSX_INSTALLER_IDENTITY:-${OSX_INSTALLER_SIGNING_IDENTITY}}"
	
	# Use bundled entitlements if not provided externally
	if [ -z "${OSX_ENTITLEMENTS}" ] || [ ! -f "${OSX_ENTITLEMENTS}" ]; then
		OSX_ENTITLEMENTS="${HERE}/../../os/macos/entitlements.plist"
	fi
	
	if [ -n "${CODESIGN_ID}" ]; then
		echo "Code-signing with identity: ${CODESIGN_ID}"
		echo "Using entitlements: ${OSX_ENTITLEMENTS}"
		
		APP_BUNDLE="${PAYLOAD_BUILD}/${BRAND}.app"
		FRAMEWORKS_DIR="${APP_BUNDLE}/Contents/Frameworks"
		PYTHON_FW="${FRAMEWORKS_DIR}/Python.framework"
		
		# =============================================================================
		# Step 0: Fix Python.framework structure (symlinks required for codesign)
		# =============================================================================
		if [ -d "${PYTHON_FW}" ]; then
			echo "🔧 Fixing Python.framework bundle structure..."
			
			# Check if Python is a file instead of a symlink
			if [ -f "${PYTHON_FW}/Python" ] && [ ! -L "${PYTHON_FW}/Python" ]; then
				echo "   Replacing top-level Python file with symlink..."
				rm -f "${PYTHON_FW}/Python"
				ln -s "Versions/Current/Python" "${PYTHON_FW}/Python"
			fi
			
			# Check if Resources is a directory instead of a symlink
			if [ -d "${PYTHON_FW}/Resources" ] && [ ! -L "${PYTHON_FW}/Resources" ]; then
				echo "   Replacing top-level Resources directory with symlink..."
				rm -rf "${PYTHON_FW}/Resources"
				ln -s "Versions/Current/Resources" "${PYTHON_FW}/Resources"
			fi
			
			# Check if Headers exists and is not a symlink
			if [ -d "${PYTHON_FW}/Headers" ] && [ ! -L "${PYTHON_FW}/Headers" ]; then
				echo "   Replacing top-level Headers directory with symlink..."
				rm -rf "${PYTHON_FW}/Headers"
				ln -s "Versions/Current/Headers" "${PYTHON_FW}/Headers"
			fi
			
			echo "✅ Python.framework structure fixed"
		fi
		
		# =============================================================================
		# Step 1: Sign Python.framework components (deepest level first)
		# =============================================================================
		if [ -d "${PYTHON_FW}" ]; then
			echo "📦 Signing Python.framework components..."
			
			# Sign all .so extension modules first
			echo "   Signing Python extension modules (.so files)..."
			find "${PYTHON_FW}" -name "*.so" -type f 2>/dev/null | while read so_file; do
				codesign --force --deep --options runtime --timestamp \
					--sign "${CODESIGN_ID}" \
					"${so_file}" 2>/dev/null || true
			done
			
			# Sign Python executables in bin/
			echo "   Signing Python executables..."
			for py_bin in python3.10 pip3; do
				PY_BIN_PATH="${PYTHON_FW}/Versions/3.10/bin/${py_bin}"
				if [ -f "${PY_BIN_PATH}" ]; then
					chmod +x "${PY_BIN_PATH}" || true
					codesign --force --deep --options runtime --timestamp \
						--sign "${CODESIGN_ID}" \
						"${PY_BIN_PATH}"
				fi
			done
			
			# Sign the main Python dylib
			echo "   Signing Python dylib..."
			PYTHON_DYLIB="${PYTHON_FW}/Versions/3.10/Python"
			if [ -f "${PYTHON_DYLIB}" ]; then
				codesign --force --deep --options runtime --timestamp \
					--sign "${CODESIGN_ID}" \
					"${PYTHON_DYLIB}"
			fi
			
			
			# Sign the entire framework bundle
			echo "   Signing Python.framework bundle..."
			codesign --force --deep --options runtime --timestamp \
				--sign "${CODESIGN_ID}" \
				"${PYTHON_FW}"
			
			echo "✅ Python.framework signed"
		else
			echo "⚠️  Python.framework not found at ${PYTHON_FW}, skipping..."
		fi
		
		# =============================================================================
		# Step 2: Sign other frameworks (if any)
		# =============================================================================
		echo "📦 Signing other frameworks..."
		find "${FRAMEWORKS_DIR}" -name "*.framework" -not -path "*/Python.framework*" -type d 2>/dev/null | while read fw; do
			codesign --force --deep --options runtime --timestamp \
				--sign "${CODESIGN_ID}" \
				"${fw}" || true
		done
		
		# Sign any dylibs in Frameworks
		find "${FRAMEWORKS_DIR}" -name "*.dylib" -type f 2>/dev/null | while read dylib; do
			codesign --force --deep --options runtime --timestamp \
				--sign "${CODESIGN_ID}" \
				"${dylib}" || true
		done
		
		# =============================================================================
		# Step 3: Sign main application executables
		# =============================================================================
		echo "⚙️  Signing main application executables..."
		
		# Ensure executables are marked as executable before signing
		for b in cellframe-node-config cellframe-node-tool cellframe-node-cli cellframe-node; do
			if [ -f "${APP_BUNDLE}/Contents/MacOS/${b}" ]; then
				chmod +x "${APP_BUNDLE}/Contents/MacOS/${b}" || true
			fi
		done
		
		# Sign helpers first, then main binary
		for bin in cellframe-node-config cellframe-node-tool cellframe-node-cli cellframe-node; do
			if [ -f "${APP_BUNDLE}/Contents/MacOS/${bin}" ]; then
				echo "   Signing ${bin}..."
				codesign --force --deep --options runtime --timestamp \
					--entitlements "${OSX_ENTITLEMENTS}" \
					--sign "${CODESIGN_ID}" \
					"${APP_BUNDLE}/Contents/MacOS/${bin}"
			fi
		done
		
		# =============================================================================
		# Step 4: Sign the entire app bundle
		# =============================================================================
		echo "📱 Signing app bundle: ${APP_BUNDLE}"
		codesign --force --deep --options runtime --timestamp \
			--entitlements "${OSX_ENTITLEMENTS}" \
			--sign "${CODESIGN_ID}" \
			"${APP_BUNDLE}"
		
		# =============================================================================
		# Step 5: Verify signatures
		# =============================================================================
		echo "🔍 Verifying signatures..."
		codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
		spctl -a -vv "${APP_BUNDLE}" || true
		
		echo "✅ Code signing completed"
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

