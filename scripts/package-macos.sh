#!/usr/bin/env bash
# Builds and packages the macOS app (a .app bundle, optionally as a .dmg).
# Intended to run on macOS or in CI.
#
# Usage:
#   ./scripts/package-macos.sh [-m MODE] [-b BUILDDIR] [--dmg]
set -e

if [ ! -e "src/api/api.h" ]; then
  echo "Please run this script from the root directory of the repository."
  exit 1
fi

source scripts/common.sh

ROOT="$(pwd -P)"
BUILD_DIR="$(get_default_build_dir)"
VERSION="$(sed -n "s/^[[:space:]]*version : '\([^']*\)',/\1/p" meson.build | head -n 1)"
[ -n "$VERSION" ] || VERSION="0.0.0"
ARCH="$(get_platform_arch)"
BUILD_TYPE="release"
MAKE_DMG=false
APP_NAME="Aayushi Code.app"

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--mode) BUILD_TYPE="$2"; shift 2 ;;
    -b|--builddir) BUILD_DIR="$2"; shift 2 ;;
    --dmg) MAKE_DMG=true ;;
    *) shift ;;
  esac
done

if [ "$(get_platform_name)" != "darwin" ]; then
  echo "This script must be run on macOS."
  exit 1
fi

if [ ! -d "$BUILD_DIR/Lite XL.app" ]; then
  echo "Building macOS app bundle..."
  ./scripts/build.sh --mode "$BUILD_TYPE" --bundle --builddir "$BUILD_DIR"
fi

mkdir -p dist
STAGE="$ROOT/dist/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

if [ -d "$BUILD_DIR/Aayushi Code.app" ]; then
  cp -R "$BUILD_DIR/Aayushi Code.app" "$STAGE/$APP_NAME"
else
  cp -R "$BUILD_DIR/Lite XL.app" "$STAGE/$APP_NAME"
fi

if [ "$MAKE_DMG" = true ]; then
  echo "==> Creating DMG..."
  ln -s /Applications "$STAGE/Applications"
  local dmg="$ROOT/dist/aayushi-code-$VERSION-$ARCH-macos.dmg"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$dmg"
  rm -f "$STAGE/Applications"
  echo "-> $dmg"
else
  echo "==> Creating ZIP..."
  local zip="$ROOT/dist/aayushi-code-$VERSION-$ARCH-macos.zip"
  (cd "$STAGE" && zip -qr "$zip" "$APP_NAME")
  echo "-> $zip"
fi

rm -rf "$STAGE"