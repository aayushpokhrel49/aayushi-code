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

if [ ! -d "$BUILD_DIR/Aayushi Code.app" ]; then
  echo "Building macOS app bundle..."
  ./scripts/build.sh --mode "$BUILD_TYPE" --bundle --builddir "$BUILD_DIR"
fi

mkdir -p dist
STAGE="$ROOT/dist/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp -R "$BUILD_DIR/Aayushi Code.app" "$STAGE/$APP_NAME"

if [ "$MAKE_DMG" = true ]; then
  echo "==> Creating DMG..."
  dmg="$ROOT/dist/aayushi-code-$VERSION-$ARCH-macos.dmg"
  draft="$ROOT/dist/.aayushi-code-draft.dmg"
  mountpoint="$ROOT/dist/.aayushi-code-mnt"
  cleanup() {
    hdiutil detach "$mountpoint" -force >/dev/null 2>&1 || true
    rm -rf "$mountpoint"
    rm -f "$draft"
  }
  trap cleanup EXIT
  rm -rf "$mountpoint"
  mkdir -p "$mountpoint"
  # Do NOT put a "/Applications" symlink in the folder passed to
  # "hdiutil create -srcfolder": hdiutil dereferences directory symlinks and
  # would copy the ENTIRE host /Applications into the image, which hangs for
  # many minutes on CI runners (full Xcode tree). Instead, create the image
  # from the app-only stage, mount it and inject the shortcut.
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDRW "$draft"
  hdiutil attach "$draft" -nobrowse -mountpoint "$mountpoint"
  ln -s /Applications "$mountpoint/Applications"
  hdiutil detach "$mountpoint"
  rm -f "$dmg"
  hdiutil convert "$draft" -format UDZO -o "$dmg"
  echo "-> $dmg"
else
  echo "==> Creating ZIP..."
  zip="$ROOT/dist/aayushi-code-$VERSION-$ARCH-macos.zip"
  (cd "$STAGE" && zip -qr "$zip" "$APP_NAME")
  echo "-> $zip"
fi

rm -rf "$STAGE"