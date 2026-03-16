#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="Render Menu"
BUNDLE_NAME="RenderMenu"
BUILD_DIR=".build/app"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME} v${VERSION}..."

# Build release binary for both architectures
swift build -c release --arch arm64 --arch x86_64

# Create .app bundle structure
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy binary
cp ".build/apple/Products/Release/${BUNDLE_NAME}" "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}" 2>/dev/null \
  || cp ".build/release/${BUNDLE_NAME}" "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

# Copy Info.plist and set version
cp "Sources/RenderMenu/Info.plist" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"

# Ad-hoc code sign (no sandbox — not distributing via App Store)
codesign --force --sign - "${APP_DIR}"

echo "Created ${APP_DIR}"

# Create zip for distribution
cd "${BUILD_DIR}"
zip -r "${BUNDLE_NAME}-${VERSION}.zip" "${APP_NAME}.app"
cd -

echo "Created ${BUILD_DIR}/${BUNDLE_NAME}-${VERSION}.zip"
echo "SHA256: $(shasum -a 256 "${BUILD_DIR}/${BUNDLE_NAME}-${VERSION}.zip" | cut -d' ' -f1)"
