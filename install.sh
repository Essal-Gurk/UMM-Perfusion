#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SOURCE="$PWD/Prebuilt/UMMPerfusionIsiX.isixplugin"
TARGET_DIR="${ISIX_PLUGIN_DIR:-$HOME/Library/Application Support/IsiX/Plugins}"
TARGET="$TARGET_DIR/UMMPerfusionIsiX.isixplugin"

if [[ ! -d "$SOURCE" ]]; then
  echo "Prebuilt plugin not found: $SOURCE" >&2
  echo "Build it first with bash build.sh /path/to/IsiXPluginKit-SDK-6.0.7.zip" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
STAGING="$(mktemp -d "$TARGET_DIR/.umm-perfusion.XXXXXX")"
STAGED="$STAGING/UMMPerfusionIsiX.isixplugin"
trap 'if [[ -d "$STAGED" ]]; then rm -rf -- "$STAGED"; fi; rmdir "$STAGING"' EXIT
ditto "$SOURCE" "$STAGED"
xattr -cr "$STAGED"
codesign --verify --deep --strict "$STAGED"

BACKUP=""
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  mkdir -p "$TARGET_DIR/../Plugin Backups"
  BACKUP_DIR="$(mktemp -d "$TARGET_DIR/../Plugin Backups/UMMPerfusionIsiX.XXXXXX")"
  BACKUP="$BACKUP_DIR/UMMPerfusionIsiX.isixplugin"
  mv "$TARGET" "$BACKUP"
fi
if ! mv "$STAGED" "$TARGET"; then
  if [[ -n "$BACKUP" ]]; then mv "$BACKUP" "$TARGET"; fi
  exit 1
fi

echo "Installed: $TARGET"
if [[ -n "$BACKUP" ]]; then echo "Previous version: $BACKUP"; fi
echo "Restart the GitHub edition of IsiX, open a 4D perfusion series and choose"
echo "UMM Perfusion in the Image Filters menu."
echo "External plugins are unavailable in the Mac App Store edition."
