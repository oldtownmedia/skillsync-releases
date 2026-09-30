#!/bin/bash
set -euo pipefail

# SkillSync installer for Apple Silicon Macs.
#
#   curl -fsSL https://raw.githubusercontent.com/oldtownmedia/skillsync-releases/main/install.sh | bash

REPO="oldtownmedia/skillsync-releases"
APP_NAME="SkillSync"
INSTALL_DIR="/Applications"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Error: this installer only runs on macOS." >&2
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "Error: SkillSync is built for Apple Silicon Macs (M1 and later) only." >&2
  exit 1
fi

echo "Fetching latest release..."
RELEASE_JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/releases/latest") || {
  echo "Error: could not read the latest release from github.com/${REPO}." >&2
  exit 1
}

read -r VERSION ASSET_URL < <(echo "$RELEASE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
url = next((a['browser_download_url'] for a in data.get('assets', []) if a['name'].endswith('aarch64.dmg')), '')
print(data.get('tag_name', ''), url)
")

if [ -z "${ASSET_URL:-}" ]; then
  echo "Error: the latest release (${VERSION:-unknown}) has no Apple Silicon DMG." >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
DMG_PATH="${TMPDIR}/${APP_NAME}.dmg"

echo "Downloading ${APP_NAME} ${VERSION}..."
curl -fSL -o "$DMG_PATH" "$ASSET_URL"

echo "Installing to ${INSTALL_DIR}..."
MOUNT_POINT=$(hdiutil attach -nobrowse -noautoopen "$DMG_PATH" | grep "/Volumes/" | awk -F'\t' '{print $NF}')

if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "Removing previous version..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

cp -R "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"
hdiutil detach "$MOUNT_POINT" -quiet

echo ""
echo "Done — ${APP_NAME} ${VERSION} installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo "Open it from Applications or run: open -a ${APP_NAME}"
