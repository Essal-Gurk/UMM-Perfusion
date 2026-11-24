#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/TestsModuleCache
xcrun swiftc -target arm64-apple-macos15.0 \
  -module-cache-path "$PWD/.build/TestsModuleCache" \
  Sources/PerfusionEngine.swift Sources/PerfusionSettings.swift Tests/PerfusionEngineTests.swift \
  -o .build/PerfusionEngineTests

# On managed Macs, freshly linked executables can be blocked when launched
# directly from Documents. A clean temporary copy avoids that path policy.
TEST_RUN_DIR="$(mktemp -d /private/tmp/UMMPerfusionTests.XXXXXX)"
trap 'rm -rf "$TEST_RUN_DIR"' EXIT
ditto .build/PerfusionEngineTests "$TEST_RUN_DIR/PerfusionEngineTests"
xattr -cr "$TEST_RUN_DIR/PerfusionEngineTests"
codesign --force --sign - "$TEST_RUN_DIR/PerfusionEngineTests"
"$TEST_RUN_DIR/PerfusionEngineTests"

LOCALIZATION_APP="$TEST_RUN_DIR/LocalizationTests.app"
mkdir -p "$LOCALIZATION_APP/Contents/MacOS" "$LOCALIZATION_APP/Contents/Resources"
cp Tests/LocalizationTests-Info.plist "$LOCALIZATION_APP/Contents/Info.plist"
/usr/bin/ruby localize.rb "$LOCALIZATION_APP/Contents/Resources"
xcrun swiftc -target arm64-apple-macos15.0 \
  -module-cache-path "$PWD/.build/TestsModuleCache" \
  Sources/Localization.swift Tests/LocalizationTests.swift \
  -o "$LOCALIZATION_APP/Contents/MacOS/LocalizationTests"
codesign --force --sign - "$LOCALIZATION_APP"
"$LOCALIZATION_APP/Contents/MacOS/LocalizationTests"
