#!/bin/bash
# Crea l'appcast di Sparkle per una release Mac: un solo elemento che punta all'archivio
# nella Release della versione. Firma l'archivio con la chiave EdDSA del Portachiavi
# (account «globy», creata da `generate_keys --account globy`): senza quella chiave
# gli aggiornamenti non si possono pubblicare (docs/DISTRIBUZIONE.md).
#
# Uso: scripts/crea-appcast.sh [archivio] [URL dell'archivio] > build/appcast.xml
# Predefiniti: build/Globy.dmg e l'URL della Release vX.Y.Z su GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE=${1:-build/Globy.dmg}
APP=build/release/Build/Products/Release/Globy.app
if [ -n "${GLOBY_APP:-}" ]; then APP=$GLOBY_APP; fi
PLIST="$APP/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$PLIST")
URL=${2:-https://github.com/Chrono-Web/GLOBY/releases/download/v$VERSION/Globy.dmg}
NOTES=https://github.com/Chrono-Web/GLOBY/releases/tag/v$VERSION

# Gli strumenti di Sparkle arrivano con il pacchetto Swift risolto da Xcode.
SIGN=$(find build ~/Library/Developer/Xcode/DerivedData -path "*artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -1)
if [ -z "$SIGN" ]; then
    echo "sign_update non trovato: compila prima Globy con Xcode" >&2
    exit 1
fi
# Stampa: sparkle:edSignature="…" length="…"
SIGNATURE=$("$SIGN" --account globy "$ARCHIVE")
DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Globy</title>
    <item>
      <title>Globy $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$NOTES</sparkle:fullReleaseNotesLink>
      <enclosure url="$URL" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML
