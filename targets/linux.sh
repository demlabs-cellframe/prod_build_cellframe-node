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

# Check for cross-compilation architecture
if [ -n "$CROSS_ARCH" ]; then
  case "$CROSS_ARCH" in
    arm64)
      CMAKE=(cmake-arm64)
      ;;
    arm32)
      CMAKE=(cmake-arm32)
      ;;
    *)
      echo "Error: Unknown cross-arch [$CROSS_ARCH]"
      exit 255
      ;;
  esac
  echo "Linux target (cross-compile for $CROSS_ARCH)"
else
  CMAKE=(cmake)
  echo "Linux target"
fi

MAKE=(make)

echo "CMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"
