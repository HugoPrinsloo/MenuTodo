#!/bin/zsh
# Builds a Mac App Store-signed MenuTodo archive and exports it for upload.
#
# Usage: scripts/appstore.sh [buildNumber]              e.g. scripts/appstore.sh 42
#        scripts/appstore.sh [buildNumber] --upload      also export straight to App Store Connect
#
# Signing uses Xcode's cloud-managed distribution certificate for team 7VT5H6VPXH
# (-allowProvisioningUpdates), so nothing has to be installed in the local keychain.
set -euo pipefail
setopt null_glob
cd "$(dirname "$0")/.."

PROJECT="MenuTodo.xcodeproj"
SCHEME="MenuTodo-AppStore"
CONFIGURATION="AppStore"
ARCHIVE="build/MenuTodo-AppStore.xcarchive"
EXPORT_DIR="build/appstore"

usage() { echo "Usage: $0 [buildNumber] [--upload]" >&2; }

BUILD=""
UPLOAD=""
for arg in "$@"; do
  case "$arg" in
    --upload)
      UPLOAD="1"
      ;;
    -*)
      usage
      exit 1
      ;;
    *)
      if [[ -n "$BUILD" ]]; then
        usage
        exit 1
      fi
      BUILD="$arg"
      ;;
  esac
done
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"

step() { echo "\n▸ $*"; }

command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }

step "Regenerating Xcode project"
xcodegen generate --quiet

step "Archiving build $BUILD"
rm -rf "$ARCHIVE"
mkdir -p build
xcodebuild archive -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE" CURRENT_PROJECT_VERSION="$BUILD" \
  -allowProvisioningUpdates

step "Verifying sandbox entitlement"
codesign -d --entitlements :- "$ARCHIVE/Products/Applications/MenuTodo.app" 2>&1 \
  | grep -q '<key>com.apple.security.app-sandbox</key><true/>' \
  || { echo "Archived app is missing the app-sandbox entitlement" >&2; exit 1; }

rm -rf "$EXPORT_DIR"
if [[ -n "$UPLOAD" ]]; then
  step "Uploading to App Store Connect"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist scripts/ExportOptions-AppStore-Upload.plist -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates
  echo "\n✓ Uploaded build $BUILD to App Store Connect"
else
  step "Exporting for the App Store"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist scripts/ExportOptions-AppStore.plist -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates

  PKG=("$EXPORT_DIR"/*.pkg)
  [[ ${#PKG[@]} -gt 0 ]] || { echo "No .pkg produced in $EXPORT_DIR" >&2; exit 1; }

  echo "\n✓ Exported build $BUILD:\n   ${PKG[1]}"
  echo "Next: upload ${PKG[1]} with Transporter.app, 'xcrun altool --upload-package', Xcode Organizer, or re-run with --upload."
fi
