#!/usr/bin/env bash
# Builds an AppImage from the portable build tree.
#
# Usage:
#   ./scripts/package-appimage.sh [-b BUILDDIR] [-v VERSION]
set -e

if [ ! -e "src/api/api.h" ]; then
  echo "Please run this script from the root directory of the repository."
  exit 1
fi

source scripts/common.sh

BUILD_DIR="$(get_default_build_dir)"
VERSION="$(sed -n "s/^[[:space:]]*version : '\([^']*\)',/\1/p" meson.build | head -n 1)"
[ -n "$VERSION" ] || VERSION="0.0.0"
ARCH="$(uname -m)"

show_help() {
  echo "Usage: $0 <OPTIONS>"
  echo "-b --builddir DIRNAME     Build dir name (default: $BUILD_DIR)."
  echo "-v --version VERSION      Override the package version."
  echo "-h --help                 Show this help."
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -b|--builddir) BUILD_DIR="$2"; shift 2 ;;
    -v|--version) VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PORTABLE_TREE="$BUILD_DIR/lite-xl"
if [ ! -x "$PORTABLE_TREE/aayushi-code" ] && [ ! -x "$PORTABLE_TREE/bin/aayushi-code" ]; then
  echo "Portable tree not found at $PORTABLE_TREE."
  echo "Build it first with: scripts/build.sh --portable"
  exit 1
fi

resolve_portable_binary() {
  if [ -x "$PORTABLE_TREE/aayushi-code" ]; then
    echo "$PORTABLE_TREE/aayushi-code"
  elif [ -x "$PORTABLE_TREE/bin/aayushi-code" ]; then
    echo "$PORTABLE_TREE/bin/aayushi-code"
  fi
}

setup_appimagetool() {
  if [ ! -e appimagetool ]; then
    if ! wget -O appimagetool \
      "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"; then
      echo "Could not download appimagetool for arch '${ARCH}'."
      exit 1
    fi
    chmod 0755 appimagetool
  fi
}

generate_appimage() {
  local appdir="AayushiCode.AppDir"
  rm -rf "$appdir"

  echo "Creating $appdir..."
  mkdir -p "$appdir/usr/bin"

  install -D -m 0755 "$(resolve_portable_binary)" "$appdir/usr/bin/aayushi-code"
  rsync -a --delete "$PORTABLE_TREE/data/" "$appdir/usr/share/aayushi-code/"
  cp resources/icons/aayushi-code.svg "$appdir/"
  cp resources/linux/com.aayushi.code.desktop "$appdir/"

  mkdir -p "$appdir/usr/share/metainfo"
  if [ -f "$PORTABLE_TREE/share/metainfo/com.aayushi.code.metainfo.xml" ]; then
    cp "$PORTABLE_TREE/share/metainfo/com.aayushi.code.metainfo.xml" \
      "$appdir/usr/share/metainfo/"
  fi

  cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
CURRENTDIR="$(dirname "$(readlink -f "$0")")"
SELF="$CURRENTDIR/usr/share/aayushi-code"
exec "$CURRENTDIR/usr/bin/aayushi-code" "$@"
EOF
  chmod +x "$appdir/AppRun"

  echo "Generating AppImage..."
  APPIMAGE_EXTRACT_AND_RUN=1 ./appimagetool "$appdir" \
    "dist/aayushi-code-$VERSION-$ARCH-linux.AppImage"
  rm -rf "$appdir"
}

mkdir -p dist
setup_appimagetool
generate_appimage
echo "-> dist/aayushi-code-$VERSION-$ARCH-linux.AppImage"