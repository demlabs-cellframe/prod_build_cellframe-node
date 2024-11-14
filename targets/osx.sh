#!/bin/bash -e
#OSX BUILD 
#HAVE TO PROVIDE OSXCROSS_QT_ROOT variable
#HAVE TO PROVIDE OSXCROSS_QT_VERSION variable

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

UNAME_OUT="$(uname -s)"
case "${UNAME_OUT}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    MSYS_NT*)   MACHINE=Git;;
    *)          MACHINE="UNKNOWN:${UNAME_OUT}"
esac

if [ "$MACHINE" != "Mac" ]
then
  echo "Host is $MACHINE, use osx-cross build target"
  if [ -z "$OSXCROSS_ROOT" ]
  then
        echo "Please, export OSXCROSS_ROOT variable, pointing to Qt-builds locations for osxcross environment"
        exit 255
  fi


  echo "Using  ${OSXCROSS_ROOT} osxcross "
  [ ! -d ${OSXCROSS_ROOT} ] && { echo "No ${OSXCROSS_ROOT} found" && exit 255; }

  $(${OSXCROSS_ROOT}/bin/osxcross-conf)


  export OSXCROSS_HOST=x86_64-apple-darwin20.4

  QT_LIBS=(-DQt5_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5/
           -DQt5Core_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Core/ 
           -DQt5Qml_DIR=//opt/osxcross/qt-5.15.13/lib/cmake/Qt5Qml/ 
           -DQt5Network_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Network 
           -DQt5PacketProtocol_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5PacketProtocol/ 
           -DQt5Quick_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Quick 
           -DQt5Gui_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Gui/ 
           -DQt5AccessibilitySupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5AccessibilitySupport/ 
           -DQt5ThemeSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5ThemeSupport/ 
           -DQt5FontDatabaseSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5FontDatabaseSupport/ 
           -DQt5GraphicsSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5GraphicsSupport/ 
           -DQt5PrintSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5PrintSupport/ 
           -DQt5Widgets_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Widgets/ 
           -DQt5ClipboardSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5ClipboardSupport/ 
           -DQt5EventDispatcherSupport_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5EventDispatcherSupport/ 
           -DQt5Svg_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Svg/ 
           -DQt5Zlib_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5Zlib/ 
           -DQt5VirtualKeyboard_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5VirtualKeyboard/
           -DQt5QmlModels_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5QmlModels
           -DQt5WebSockets_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5WebSockets
           -DQt5QuickWidgets_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5QuickWidgets
           -DQt5QuickControls2_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5QuickControls2
           -DQt5QmlWorkerScript_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5QmlWorkerScript
           -DQt5QmlImportScanner_DIR=/opt/osxcross/qt-5.15.13/lib/cmake/Qt5QmlImportScanner) 

  CMAKE=(cmake -DCMAKE_TOOLCHAIN_FILE=${OSXCROSS_ROOT}/toolchain.cmake ${QT_LIBS[@]})

  ##everything else can be done by default make
  MAKE=(make)

  
else
    echo "Host is $MACHINE, use native build toolchain"

    if [ -f "/Users/$USER/Qt/Tools/CMake/CMake.app/Contents/bin/cmake" ] 
    then
      CMAKE=(/Users/$USER/Qt/Tools/CMake/CMake.app/Contents/bin/cmake )
      echo "Found QT cmake at $CMAKE, using it preferable"
    else
      if [ -f "/opt/homebrew/bin/cmake" ] 
      then
        CMAKE=(/opt/homebrew/bin/cmake)
        echo "Found homebrew cmake at $CMAKE, using it"
      else
        echo "Not found cmake at default qt location, asuming it is in PATH"
        CMAKE=(cmake)
      fi
    fi

    ##everything else can be done by default make
    MAKE=(make)
fi
echo "CMAKE=${CMAKE[@]}"
echo "MAKE=${MAKE[@]}"
