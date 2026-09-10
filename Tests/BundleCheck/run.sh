#!/bin/bash
# Builds a throwaway Check.app laid out exactly like build.sh lays out Vaani.app
# (binary in Contents/MacOS, SwiftPM resource bundles in Contents/Resources), moves it
# away from the .build directory so SwiftPM's hardcoded fallback path cannot mask a
# failure, and constructs a KeyboardShortcuts recorder. Exit 0 = fixed, non-zero = crash.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release 2>&1 | tail -1
OUT=$(mktemp -d)
APP="$OUT/Check.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BundleCheck "$APP/Contents/MacOS/BundleCheck"
cp -R .build/release/*.bundle "$APP/Contents/Resources/"
printf '<plist version="1.0"><dict><key>CFBundleExecutable</key><string>BundleCheck</string><key>CFBundleIdentifier</key><string>com.vaani.bundlecheck</string></dict></plist>' > "$APP/Contents/Info.plist"
rm -rf .build
"$APP/Contents/MacOS/BundleCheck"
