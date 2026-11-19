#!/bin/bash
# Compila Clau i la deixa a /Applications/Clau.app, com a app d'iPhone que corre al Mac.
set -e
cd "$(dirname "$0")"
xcodebuild -project Clau.xcodeproj -scheme Clau -configuration Release \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  -derivedDataPath build/ddmac -allowProvisioningUpdates build | grep -E "error|BUILD"
APP=/Applications/Clau.app
osascript -e 'quit app id "cat.sergicastillo.clau"' 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Wrapper"
cp -R build/ddmac/Build/Products/Release-iphoneos/Clau.app "$APP/Wrapper/Clau.app"
ln -s Wrapper/Clau.app "$APP/WrappedBundle"
open "$APP"
echo "Instal·lada a $APP i oberta"
