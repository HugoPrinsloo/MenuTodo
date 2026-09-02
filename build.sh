#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

xcodegen generate

xcodebuild -project MenuTodo.xcodeproj \
  -scheme MenuTodo \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build

APP_PATH="build/DerivedData/Build/Products/Release/MenuTodo.app"

mkdir -p build
rm -rf build/MenuTodo.app
cp -R "$APP_PATH" build/MenuTodo.app

echo "Built app: $(cd build && pwd)/MenuTodo.app"
