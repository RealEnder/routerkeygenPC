#!/bin/sh

#CMAKE_PREFIX_PATH should be defined to somehting like ~/Qt/5.3/clang_64


SRC_FOLDER=`pwd` #assumed to be the current folder, change to compile in another location
ROOT_FOLDER=`pwd`
BUILD_FOLDER=$ROOT_FOLDER/mac
BACKGROUND_NAME=background.png
BACKGROUND_LOCATION=$ROOT_FOLDER/share/$BACKGROUND_NAME
DMG_NAME=RouterKeygen_V1_1_0
TITLE=RouterKeygen
APPLICATION_NAME="$TITLE".app

mkdir -p $BUILD_FOLDER
cd $BUILD_FOLDER

command -v qmake >/dev/null 2>&1 || { echo >&2 "qmake is required for building.  Aborting."; exit 1; }

QMAKE=`command -v qmake`
#remove qmake from path
CMAKE_PREFIX_PATH=`dirname $QMAKE`
#remove bin from path
CMAKE_PREFIX_PATH=`dirname $CMAKE_PREFIX_PATH`

cmake -DCMAKE_BUILD_TYPE=Release -DQT_QMAKE_EXECUTABLE=`command -v qmake` "$SRC_FOLDER"
if [ "$?" = "0" ]; then	
	if [ -f bin/RouterKeygen.app ];
	then
		rm bin/RouterKeygen.app
	fi
	make
else
	echo "Could not create Makefiles" 1>&2
	exit 1
fi

if [ "$?" = "0" ]; then
    macdeployqt bin/routerkeygen.app -always-overwrite
    mv bin/routerkeygen.app bin/RouterKeygen.app
    #Allow codesign to work properly
    cp "$CMAKE_PREFIX_PATH"/lib/QtCore.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtCore.framework/Resources/
    cp "$CMAKE_PREFIX_PATH"/lib/QtGui.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtGui.framework/Resources/
    cp "$CMAKE_PREFIX_PATH"/lib/QtWidgets.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtWidgets.framework/Resources/
    cp "$CMAKE_PREFIX_PATH"/lib/QtNetwork.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtNetwork.framework/Resources/
    cp "$CMAKE_PREFIX_PATH"/lib/QtScript.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtScript.framework/Resources/
    cp "$CMAKE_PREFIX_PATH"/lib/QtPrintSupport.framework/Resources/Info.plist bin/RouterKeygen.app/Contents/Frameworks/QtPrintSupport.framework/Resources/
else
    echo "Error while building" 1>&2
    exit 1
fi


if [ -f pack.temp.dmg ];
then
	rm pack.temp.dmg
fi

mkdir -p bin/.background
cp "${BACKGROUND_LOCATION}" bin/.background
hdiutil create -srcfolder bin -volname "${TITLE}" -fs HFS+ \
-fsargs "-c c=64,a=16,e=16" -format UDRW -size 100000k pack.temp.dmg

device=$(hdiutil attach -readwrite -noverify -noautoopen "pack.temp.dmg" | \
egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 5

echo '
tell application "Finder"
with timeout of 300 seconds
	tell disk "'${TITLE}'"
	with timeout of 300 seconds
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set the bounds of container window to {400, 100, 885, 430}
		set theViewOptions to the icon view options of container window
		set arrangement of theViewOptions to not arranged
		set icon size of theViewOptions to 128
		set background picture of theViewOptions to file ".background:'${BACKGROUND_NAME}'"
		make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
		set position of item "'${APPLICATION_NAME}'" of container window to {110, 180}
		set position of item "Applications" of container window to {375, 180}
		set position of item ".Trashes" of container window to {110, 400}
		set position of item ".DS_Store" of container window to {375, 400}
		set position of item ".background" of container window to {110, 500}
		set position of item ".fseventsd" of container window to {375, 500}
		close
		open
		update without registering applications
		delay 5
	end
	end tell
end
end tell
' | osascript

chmod -Rf go-w /Volumes/"${TITLE}"
sync
sync
hdiutil detach ${device}
rm -f "${DMG_NAME}".dmg
hdiutil convert pack.temp.dmg -format UDBZ -imagekey bzip2-level=9 -o "${DMG_NAME}"
rm -f pack.temp.dmg
