#!/bin/bash
#
# Build "Poster" as a standalone macOS .app, then install it or package a DMG.
# Requires Xcode (which includes xcodebuild) to be installed.
#
# Usage:
#   cd ~/Claude/Projects/Poster
#   ./build.sh install   # build and install to /Applications
#   ./build.sh dmg       # build and package dist/Poster.dmg
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Poster"
BUILD_DIR="build"
DIST_DIR="dist"
CONFIG="Release"
MODE="${1:-install}"

usage() {
  echo "Usage: ./build.sh [install|dmg]"
}

case "${MODE}" in
  install|dmg)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

echo "▸ Building ${APP_NAME} (${CONFIG})…"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration "${CONFIG}" \
  -derivedDataPath "${BUILD_DIR}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  clean build

APP_PATH="${BUILD_DIR}/Build/Products/${CONFIG}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
  echo "✗ Build failed: ${APP_PATH} not found."
  exit 1
fi

if [ "${MODE}" = "install" ]; then
  echo "▸ Installing to /Applications…"
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "${APP_PATH}" "/Applications/"

  echo "✓ Done. ${APP_NAME}.app is now in /Applications."
  open -R "/Applications/${APP_NAME}.app"
  exit 0
fi

echo "▸ Packaging DMG…"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/dmg-root"
cp -R "${APP_PATH}" "${DIST_DIR}/dmg-root/"
ln -s /Applications "${DIST_DIR}/dmg-root/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DIST_DIR}/dmg-root" \
  -ov \
  -format UDZO \
  "${DIST_DIR}/${APP_NAME}.dmg"

rm -rf "${DIST_DIR}/dmg-root"

echo "✓ Done. DMG created at ${DIST_DIR}/${APP_NAME}.dmg."
open -R "${DIST_DIR}/${APP_NAME}.dmg"
