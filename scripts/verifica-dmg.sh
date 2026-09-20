#!/bin/bash
# Verifica che un DMG di Globy contenga l'app e il layout Finder personalizzato.
# Uso: scripts/verifica-dmg.sh <Globy.dmg> [versione attesa]
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Uso: $0 <Globy.dmg> [versione attesa]" >&2
    exit 2
fi

ARCHIVE=$1
EXPECTED_VERSION=${2:-}
if [ ! -f "$ARCHIVE" ]; then
    echo "Errore: DMG non trovato: $ARCHIVE" >&2
    exit 1
fi

MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/globy-dmg-verifica.XXXXXX")
DEVICE=""

cleanup() {
    if [ -n "$DEVICE" ]; then
        hdiutil detach "$DEVICE" -quiet >/dev/null 2>&1 || true
    fi
    if [ -d "$MOUNT" ]; then
        rmdir "$MOUNT" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

ATTACH_OUTPUT=$(hdiutil attach "$ARCHIVE" -readonly -noverify -noautoopen -mountpoint "$MOUNT")
DEVICE=$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1}')
if [ -z "$DEVICE" ]; then
    echo "Errore: impossibile individuare il volume HFS nel DMG." >&2
    exit 1
fi

if [ ! -d "$MOUNT/Globy.app" ] || [ ! -L "$MOUNT/Applicazioni" ]; then
    echo "Errore: nel DMG mancano Globy.app o il collegamento Applicazioni." >&2
    exit 1
fi

for REQUIRED in \
    "$MOUNT/Globy.app/Contents/Info.plist" \
    "$MOUNT/Installa e disinstalla Globy.txt" \
    "$MOUNT/.background/sfondo.tiff" \
    "$MOUNT/.DS_Store"
do
    if [ ! -e "$REQUIRED" ] || [ ! -s "$REQUIRED" ]; then
        echo "Errore: nel DMG manca un elemento richiesto: $REQUIRED" >&2
        exit 1
    fi
done

LAYOUT_RECORDS=$(strings "$MOUNT/.DS_Store")
for RECORD in bwsp icvp Iloc sfondo.tiff; do
    case "$LAYOUT_RECORDS" in
        *"$RECORD"*) ;;
        *)
            echo "Errore: il .DS_Store non contiene il record di layout '$RECORD'." >&2
            exit 1
            ;;
    esac
done

ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
    "$MOUNT/Globy.app/Contents/Info.plist")
if [ -n "$EXPECTED_VERSION" ] && [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "Errore: il DMG contiene Globy $ACTUAL_VERSION, attesa $EXPECTED_VERSION." >&2
    exit 1
fi

hdiutil detach "$DEVICE" -quiet
DEVICE=""
rmdir "$MOUNT"
echo "DMG verificato: Globy $ACTUAL_VERSION, layout Finder presente."
