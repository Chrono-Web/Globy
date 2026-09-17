#!/bin/bash
# Crea build/Globy-<versione>.dmg e la copia stabile build/Globy.dmg (nome usato
# dalla Release GitHub e dal README). Finestra con sfondo e freccia, Globy.app,
# collegamento ad Applicazioni e istruzioni. Non firma e non notarizza
# (docs/DISTRIBUZIONE.md). La disposizione della finestra la scrive il Finder:
# la prima volta macOS può chiedere il permesso di controllarlo.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Globy.xcodeproj -scheme Globy -configuration Release \
    -derivedDataPath build/release build -quiet

APP=build/release/Build/Products/Release/Globy.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
WORK=build/dmg
STAGE="$WORK/Globy"
RW="$WORK/Globy-rw.dmg"
OUT="build/Globy-$VERSION.dmg"
STABLE="build/Globy.dmg"
VOLUME="Globy"
GUIDE="Installa e disinstalla Globy.txt"

rm -rf "$WORK" "$OUT" "$STABLE"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/Globy.app"
ln -s /Applications "$STAGE/Applicazioni"
cp "scripts/dmg/$GUIDE" "$STAGE/"
swift scripts/dmg/sfondo.swift "$WORK"
tiffutil -cathidpicheck "$WORK/sfondo.png" "$WORK/sfondo@2x.png" -out "$STAGE/.background/sfondo.tiff" >/dev/null

# Un volume con lo stesso nome già montato confonderebbe il Finder.
if [ -d "/Volumes/$VOLUME" ]; then hdiutil detach "/Volumes/$VOLUME" -quiet || true; fi

hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEVICE=$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | awk '/Apple_HFS/ {print $1}')

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 480 pt di contenuto più la barra del titolo; in basso resta margine per la
        -- barra del percorso, se chi apre il DMG la tiene visibile.
        set the bounds of container window to {200, 120, 860, 628}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:sfondo.tiff"
        set position of item "Globy.app" of container window to {170, 200}
        set position of item "Applicazioni" of container window to {490, 200}
        set position of item "$GUIDE" of container window to {330, 360}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

chmod -Rf go-w "/Volumes/$VOLUME" || true
sync
hdiutil detach "$DEVICE" -quiet
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -rf "$WORK"
cp "$OUT" "$STABLE"
echo "$OUT"
echo "$STABLE"
