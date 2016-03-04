#!/bin/sh
set -e

cd src/
xcodebuild -project denymount.xcodeproj -target denymount -configuration Release

if [ -f "build/Release/denymount" ]; then
  cp -pR 'build/Release/denymount' '../bin/denymount'
fi

rm -rf build/
