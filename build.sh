#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

SDK_SOURCE="${1:-${UMM_PERFUSION_SDK:-$PWD/.build/IsiXPluginKit-SDK-6.0.7.zip}}"
BUILD_DIR="$PWD/.build"
mkdir -p "$BUILD_DIR/ModuleCache"

if [[ -d "$SDK_SOURCE/IsiXPluginKit.framework" ]]; then
  FRAMEWORK_DIR="$(cd "$SDK_SOURCE" && pwd)"
elif [[ -f "$SDK_SOURCE" ]]; then
  rm -rf "$BUILD_DIR/sdk"
  mkdir -p "$BUILD_DIR/sdk"
  ditto -x -k "$SDK_SOURCE" "$BUILD_DIR/sdk"
  FRAMEWORK_PATH="$(find "$BUILD_DIR/sdk" -name IsiXPluginKit.framework -type d -print -quit)"
  if [[ -z "$FRAMEWORK_PATH" ]]; then
    echo "IsiXPluginKit.framework was not found in: $SDK_SOURCE" >&2
    exit 1
  fi
  FRAMEWORK_DIR="$(dirname "$FRAMEWORK_PATH")"
else
  echo "IsiXPluginKit SDK 1.0.0 not found: $SDK_SOURCE" >&2
  echo "Usage: bash build.sh /path/to/IsiXPluginKit-SDK-6.0.7.zip" >&2
  exit 1
fi
/usr/bin/ruby verify-sdk.rb "$FRAMEWORK_DIR"

BUNDLE="$BUILD_DIR/UMMPerfusionIsiX.isixplugin"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Info.plist "$BUNDLE/Contents/Info.plist"
cp LICENSE THIRD_PARTY.md "$BUNDLE/Contents/Resources/"
cp docs/REGULATORY.md "$BUNDLE/Contents/Resources/REGULATORY.md"
cp "$FRAMEWORK_DIR/SDK.json" "$BUNDLE/Contents/Resources/SDK.json"
/usr/bin/ruby localize.rb "$BUNDLE/Contents/Resources"

xcrun swiftc -module-name UMMPerfusionIsiX -parse-as-library \
  -O -target arm64-apple-macos15.0 \
  -F "$FRAMEWORK_DIR" \
  -module-cache-path "$BUILD_DIR/ModuleCache" \
  -framework IsiXPluginKit -framework AppKit -framework SwiftUI \
  -Xlinker -bundle \
  -o "$BUNDLE/Contents/MacOS/UMMPerfusionIsiX" Sources/*.swift

xattr -cr "$BUNDLE"
codesign --force --sign - "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"
echo "Build complete: $BUNDLE"
