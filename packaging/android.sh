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

#check if we can sign apk
APK_SIGN_POSSIBLE=1
if [ -z "$ANDROID_KEYSTORE_PATH" ]
then
      echo "No ANDROID_KEYSTORE_PATH provided. APK will NOT be signed"
      APK_SIGN_POSSIBLE=0
fi

if [ -z "$ANDROID_KEYSTORE_ALIAS" ]
then
      echo "No ANDROID_KEYSTORE_ALIAS provided. APK will NOT be signed"
      APK_SIGN_POSSIBLE=0
fi

if [ -z "$ANDROID_KEYSTORE_PASS" ]
then
    echo "No ANDROID_KEYSTORE_PASS provided. APK will NOT be signed"
    APK_SIGN_POSSIBLE=0
fi



FILL_VERSION()
{
    source "${HERE}/../version.mk"

    VERSION_UPDATE="s|VERSION_MAJOR|${VERSION_MAJOR}|g"
    BUILD_UPDATE="s|VERSION_MINOR|${VERSION_MINOR}|g"
    MAJOR_UPDATE="s|VERSION_PATCH|${VERSION_PATCH}|g"

    for TEMPLATE in "$@"; do
        sed \
            -e "${VERSION_UPDATE}" \
            -e "${BUILD_UPDATE}" \
            -e "${MAJOR_UPDATE}" \
            -i "${TEMPLATE}"
    done
}

PACK() 
{
    
    DIST_DIR=$1
    BUILD_DIR=$2
    OUT_DIR=$3

    cd $HERE/../../os/android
    ./gradlew assembleRelease

    if [ "$APK_SIGN_POSSIBLE" -eq "1" ]; then
        apksigner sign --ks-key-alias $ANDROID_KEYSTORE_ALIAS --ks $ANDROID_KEYSTORE_PATH --ks-pass pass:"$ANDROID_KEYSTORE_PASS" --in ./app/build/outputs/apk/release/app-release.apk --out ../../CellframeNode.apk
    fi
}
