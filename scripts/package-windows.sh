#!/usr/bin/env bash
# Builds the Windows package (portable .zip) from a release build.
# Intended to run on Windows (MSYS2/Git Bash) or in CI.
#
# Usage:
#   ./scripts/package-windows.sh [-m MODE] [-b BUILDDIR]
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
ARCHIVE="$ROOT/dist/aayushi-code-$VERSION-$ARCH-windows.zip"

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--mode) BUILD_TYPE="$2"; shift 2 ;;
    -b|--builddir) BUILD_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PORTABLE_TREE="$BUILD_DIR/aayushi-code"
if [ ! -x "$PORTABLE_TREE/aayushi-code$(get_executable_extension)" ]; then
  echo "Building portable tree..."
  ./scripts/build.sh --mode "$BUILD_TYPE" --portable --builddir "$BUILD_DIR"
fi

mkdir -p dist
echo "==> Creating Windows archive..."
if command -v zip >/dev/null 2>&1; then
  (cd "$BUILD_DIR" && zip -qr "$ARCHIVE" aayushi-code)
else
  case "$(get_platform_name)" in
    windows)
      powershell -NoProfile -Command "Compress-Archive -Force -Path '$PORTABLE_TREE' -DestinationPath '$ARCHIVE'" ;;
    *)
      echo "zip utility not found and no archiver available."
      exit 1 ;;
  esac
fi

echo "-> $ARCHIVE"

# Also produce a setup installer when Inno Setup is available
if [ -n "$ISCC" ] || [ -d "/c/Program Files (x86)/Inno Setup 6" ] || [ -d "/c/Program Files/Inno Setup 6" ]; then
  echo "==> Building setup installer..."
  ./scripts/package-innosetup.sh --builddir "$BUILD_DIR"
fi