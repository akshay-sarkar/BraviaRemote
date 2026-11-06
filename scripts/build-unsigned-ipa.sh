#!/usr/bin/env bash
# Builds BraviaRemote-unsigned.ipa for Sideloadly / AltStore / other re-signers.
# It isn't signed with any developer certificate; it only carries an ad-hoc signature
# so the entitlements travel with it.
# Requires macOS with Xcode 16+.
#
# Optional environment variables:
#   MARKETING_VERSION  app version shown to users (e.g. 1.2.0)
#   BUILD_NUMBER       build number (CFBundleVersion)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"

rm -rf "$BUILD"
mkdir -p "$BUILD"

xcodebuild -version

xcodebuild \
  -project BraviaRemote.xcodeproj \
  -target BraviaRemote \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$BUILD" \
  OBJROOT="$BUILD/obj" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ${MARKETING_VERSION:+MARKETING_VERSION="$MARKETING_VERSION"} \
  ${BUILD_NUMBER:+CURRENT_PROJECT_VERSION="$BUILD_NUMBER"} \
  build

APP="$BUILD/Release-iphoneos/BraviaRemote.app"
[ -d "$APP" ] || { echo "error: $APP not found" >&2; exit 1; }

# Embed the entitlements (app group for widgets, Siri and Control Center) with an
# ad-hoc signature. Sideloadly / AltStore read them from here when they re-sign
# the app with your Apple ID. Without this, widgets can't see your paired TVs.
APPEX="$APP/PlugIns/BraviaRemoteWidgets.appex"
if [ -d "$APPEX" ]; then
  codesign --force --sign - --timestamp=none --entitlements BraviaRemoteWidgets.entitlements "$APPEX"
fi
codesign --force --sign - --timestamp=none --entitlements BraviaRemote.entitlements "$APP"
echo "Embedded entitlements:"
codesign -d --entitlements - "$APP" 2>/dev/null || true

mkdir -p "$BUILD/Payload"
cp -R "$APP" "$BUILD/Payload/"
(cd "$BUILD" && zip -qry BraviaRemote-unsigned.ipa Payload)

echo "IPA: $BUILD/BraviaRemote-unsigned.ipa"
ls -lh "$BUILD/BraviaRemote-unsigned.ipa"
