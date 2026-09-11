#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMEBREW_APPS_DIR="$(cd "$ROOT_DIR/../homebrew-apps" && pwd)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command not found: $1" >&2
    exit 1
  fi
}

for cmd in git xcodebuild asc gh shasum spctl; do
  require_command "$cmd"
done

cd "$ROOT_DIR"

# 1. Determine version
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  if [[ -f "project.yml" ]]; then
    VERSION="$(grep 'MARKETING_VERSION:' project.yml | head -n 1 | awk '{print $2}' | tr -d '"')"
  fi
fi

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release-local.sh [version, e.g. 0.1.0]" >&2
  exit 1
fi

TAG="v$VERSION"
echo "=== Starting local release for AccessDeck $TAG with Apple Notarization ==="

# 2. Run developer-id build & notarization
echo "--> Building, signing with Developer ID and notarizing via Apple Notary Service..."
DISTRIBUTION_MODE=developer-id "$ROOT_DIR/scripts/package-app.sh"

DMG_FILE="$ROOT_DIR/dist/accessdeck-${VERSION}.dmg"
DMG_INVARIANT="$ROOT_DIR/dist/AccessDeck.dmg"
ZIP_FILE="$ROOT_DIR/dist/AccessDeck.zip"

if [[ ! -f "$DMG_FILE" ]]; then
  echo "Error: Expected DMG file not found at $DMG_FILE" >&2
  exit 1
fi

DMG_SHA256="$(shasum -a 256 "$DMG_FILE" | awk '{print $1}')"
ZIP_SHA256="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"

echo "DMG SHA256: $DMG_SHA256"
echo "ZIP SHA256: $ZIP_SHA256"

# 3. Publish to GitHub Releases
echo "--> Publishing to GitHub Releases ($TAG)..."
if gh release view "$TAG" --repo LanrenwenStudio/AccessDeck >/dev/null 2>&1; then
  echo "Release $TAG exists, uploading / updating assets..."
  gh release upload "$TAG" "$DMG_FILE" "$DMG_INVARIANT" "$ZIP_FILE" --repo LanrenwenStudio/AccessDeck --clobber
else
  echo "Creating new GitHub Release $TAG..."
  gh release create "$TAG" "$DMG_FILE" "$DMG_INVARIANT" "$ZIP_FILE" \
    --repo LanrenwenStudio/AccessDeck \
    --title "$TAG" \
    --notes "AccessDeck $TAG - macOS menu bar utility for monitoring CLIProxyAPI account quotas."
fi

# 4. Update local and homebrew-apps Casks
echo "--> Updating Homebrew Cask in AccessDeck repo and homebrew-apps repo..."
update_cask() {
  local cask_path="$1"
  if [[ -f "$cask_path" ]]; then
    sed -i '' -e "s/version \".*\"/version \"$VERSION\"/" "$cask_path"
    sed -i '' -e "s/sha256 \".*\"/sha256 \"$DMG_SHA256\"/" "$cask_path"
    sed -i '' -e "s/sha256 :no_check/sha256 \"$DMG_SHA256\"/" "$cask_path"
    sed -i '' -e 's|download/v#{version}/.*\.zip|download/v#{version}/accessdeck-#{version}.dmg|' "$cask_path"
    sed -i '' -e 's|download/v#{version}/.*\.dmg|download/v#{version}/accessdeck-#{version}.dmg|' "$cask_path"
  fi
}

update_cask "$ROOT_DIR/Casks/clipbar.rb"

if [[ -d "$HOMEBREW_APPS_DIR" ]]; then
  update_cask "$HOMEBREW_APPS_DIR/Casks/clipbar.rb"
  
  echo "--> Committing and pushing Homebrew Cask to homebrew-apps repository..."
  (
    cd "$HOMEBREW_APPS_DIR"
    git add Casks/clipbar.rb
    if ! git diff --cached --quiet; then
      git commit -m "chore: update AccessDeck cask to $VERSION (notarized DMG)"
      git push origin main
    else
      echo "No cask changes in homebrew-apps to commit."
    fi
  )
fi

echo ""
echo "=========================================================="
echo "🎉 AccessDeck $TAG released successfully with Apple Notarization!"
echo "📦 Release URL: https://github.com/LanrenwenStudio/AccessDeck/releases/tag/$TAG"
echo "🍺 Homebrew Cask: Updated with SHA256 ($DMG_SHA256)"
echo "🌐 Direct Download: https://github.com/LanrenwenStudio/AccessDeck/releases/latest/download/AccessDeck.dmg"
echo "=========================================================="
