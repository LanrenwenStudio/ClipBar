#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClipBar.xcodeproj"
SCHEME="ClipBar"
APP_NAME="ClipBar"
BUILD_STAMP="$(date +%Y%m%d-%H%M%S)-$$"
WORK_DIR="$ROOT_DIR/.build/package/$BUILD_STAMP"
DERIVED_DATA_PATH="$WORK_DIR/DerivedData"
STAGING_DIR="$WORK_DIR/DMG"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$WORK_DIR/Export"
EXPORT_OPTIONS_PATH="$WORK_DIR/ExportOptionsDeveloperID.plist"
APP_PATH=""
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_FILENAME="${PACKAGE_FILENAME:-}"
DISTRIBUTION_MODE="${DISTRIBUTION_MODE:-local}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-X37879TD5Q}"
DEVELOPER_IDENTITY="${DEVELOPER_IDENTITY:-6642B7BEA10EFDAFC9E813E6C2BB98358AE46AF6}"
DEVID_KEYCHAIN="${DEVID_KEYCHAIN:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

build_local_app() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED="NO" \
    build

  APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
}

build_developer_id_app() {
  require_command security
  require_command codesign
  require_command xcrun
  require_command spctl

  if [[ ! "$DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "DEVELOPMENT_TEAM must be a 10-character Apple team ID." >&2
    exit 1
  fi

  local signing_keychain="${DEVID_KEYCHAIN:-}"
  if ! security find-certificate -a -c "Developer ID Application:" ${signing_keychain:+"$signing_keychain"} >/dev/null 2>&1; then
    echo "No Developer ID Application identity is available in the current keychain." >&2
    exit 1
  fi

  xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_IDENTITY" \
    ${signing_keychain:+OTHER_CODE_SIGN_FLAGS="--keychain $signing_keychain"}

  cat >"$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>$DEVELOPER_IDENTITY</string>
  <key>teamID</key>
  <string>$DEVELOPMENT_TEAM</string>
</dict>
</plist>
EOF

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH"

  APP_PATH="$EXPORT_DIR/$APP_NAME.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Export failed: app bundle not found at $APP_PATH" >&2
    exit 1
  fi

  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  local signing_info
  signing_info="$(codesign -dvvv "$APP_PATH" 2>&1)"
  if ! grep -Fq "Authority=Developer ID Application:" <<<"$signing_info"; then
    echo "Exported app is not signed with Developer ID Application: $signing_info" >&2
    exit 1
  fi
  if ! grep -Fq "Timestamp=" <<<"$signing_info"; then
    echo "Exported app is missing a secure timestamp: $signing_info" >&2
    exit 1
  fi
}

main() {
  require_command xcodebuild
  require_command hdiutil
  require_command shasum
  require_command /usr/libexec/PlistBuddy

  if [[ ! -d "$PROJECT_PATH" ]]; then
    xcodegen generate
  fi

  case "$DISTRIBUTION_MODE" in
    local)
      build_local_app
      ;;
    developer-id)
      build_developer_id_app
      ;;
    *)
      echo "DISTRIBUTION_MODE must be 'local' or 'developer-id'." >&2
      exit 1
      ;;
  esac

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded but app bundle was not found: $APP_PATH" >&2
    exit 1
  fi

  mkdir -p "$DIST_DIR"
  mkdir -p "$STAGING_DIR"

  local version
  local build_number
  local package_name
  local package_path
  local working_package_path
  local checksum

  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
  build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"

  if [[ -n "$PACKAGE_FILENAME" ]]; then
    package_name="$PACKAGE_FILENAME"
  elif [[ "$DISTRIBUTION_MODE" == "developer-id" ]]; then
    package_name="clipbar-${version}.dmg"
  else
    package_name="clipbar-${version}-local.dmg"
  fi

  package_path="$DIST_DIR/$package_name"
  working_package_path="$WORK_DIR/$package_name"

  cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
  ln -s /Applications "$STAGING_DIR/Applications"

  rm -f "$working_package_path"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$working_package_path" >/dev/null

  # Also package universal zip
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/$APP_NAME.zip"

  if [[ "$DISTRIBUTION_MODE" == "developer-id" ]]; then
    echo "Signing DMG package with Developer ID..."
    codesign --force --timestamp --sign "$DEVELOPER_IDENTITY" "$working_package_path"

    if [[ -n "${NOTARYTOOL_KEY_PATH:-}" ]]; then
      xcrun notarytool submit "$working_package_path" --key "$NOTARYTOOL_KEY_PATH" --key-id "$NOTARYTOOL_KEY_ID" --issuer "$NOTARYTOOL_ISSUER_ID" --wait
    elif command -v asc >/dev/null 2>&1; then
      echo "Submitting to Apple Notary Service via asc CLI..."
      asc notarization submit --file "$working_package_path" --wait --output table
    else
      echo "Neither NOTARYTOOL_KEY_PATH nor asc CLI available, skipping notarization." >&2
    fi
    xcrun stapler staple "$working_package_path"
    xcrun stapler validate "$working_package_path"
    xcrun stapler staple "$STAGING_DIR/$APP_NAME.app" || true
    ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/$APP_NAME.app" "$DIST_DIR/$APP_NAME.zip"
    hdiutil verify "$working_package_path" >/dev/null
    spctl --assess --type execute --verbose=2 "$STAGING_DIR/$APP_NAME.app"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$working_package_path"
  fi

  mv -f "$working_package_path" "$package_path"
  checksum="$(shasum -a 256 "$package_path" | awk '{print $1}')"
  zip_checksum="$(shasum -a 256 "$DIST_DIR/$APP_NAME.zip" | awk '{print $1}')"

  cat <<EOF
Created package:
  DMG: $package_path (SHA256: $checksum)
  ZIP: $DIST_DIR/$APP_NAME.zip (SHA256: $zip_checksum)
EOF
}

main "$@"
