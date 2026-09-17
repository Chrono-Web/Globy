#!/bin/bash
# Crea build/Globy-<versione>.dmg con l'app Release, un collegamento ad Applicazioni
# e le istruzioni di installazione e disinstallazione. Non firma e non notarizza
# (docs/DISTRIBUZIONE.md).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Globy.xcodeproj -scheme Globy -configuration Release \
    -derivedDataPath build/release build -quiet

APP=build/release/Build/Products/Release/Globy.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE=build/dmg/Globy
OUT="build/Globy-$VERSION.dmg"

rm -rf build/dmg "$OUT"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Globy.app"
ln -s /Applications "$STAGE/Applicazioni"
cp "scripts/dmg/Installa e disinstalla Globy.txt" "$STAGE/"

hdiutil create -volname "Globy" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
rm -rf build/dmg
echo "$OUT"
