#!/bin/sh
# Builds build/GrowBox.app (release, ad-hoc signed - runs locally,
# no Apple account, no expiry).
# ./build.sh install: also copies it to ~/Applications and (re)starts it -
# the copy there is the one that opens at login.
set -e
cd "$(dirname "$0")"

swift build -c release

APP="build/GrowBox.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GrowBox "$APP/Contents/MacOS/GrowBox"
mkdir -p "$APP/Contents/Resources"
cp Resources/Ionicons.ttf "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>GrowBox</string>
  <key>CFBundleIdentifier</key><string>pl.umatik.growbox</string>
  <key>CFBundleExecutable</key><string>GrowBox</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Reads temperature, humidity and fan state from the grow box ESP in your home network.</string>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$1" = "install" ]; then
  pkill -f "GrowBox.app/Contents/MacOS/GrowBox" || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/GrowBox.app"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/GrowBox.app"
  echo "Installed to ~/Applications"
fi
