#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/MeetingBar.app
ARCH=$(uname -m)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"

swiftc -O \
    -target "${ARCH}-apple-macos14.0" \
    Sources/main.swift \
    -o "$APP/Contents/MacOS/MeetingBar" \
    -framework AppKit \
    -framework EventKit

codesign --force --sign - "$APP"
echo "Built $APP"
