#!/usr/bin/env bash
# Builds the Windows setup installer (.exe) with Inno Setup.
# Intended to run on Windows (MSYS2/Git Bash) or in CI.
#
# Usage:
#   ./scripts/package-innosetup.sh [-b BUILDDIR] [-v VERSION]
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

# Locate Inno Setup compiler
if [ -n "$ISCC" ]; then
  ISCC_EXE="$ISCC"
else
  for cand in \
    "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" \
    "/c/Program Files/Inno Setup 6/ISCC.exe" \
    "ISCC.exe"; do
    if [ -f "$cand" ]; then
      ISCC_EXE="$cand"
      break
    fi
  done
fi
if [ -z "$ISCC_EXE" ]; then
  echo "Inno Setup 6 compiler not found. Install it or set the ISCC variable."
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -b|--builddir) BUILD_DIR="$2"; shift 2 ;;
    -v|--version) VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$MSYSTEM" in
  MINGW64|UCRT64|CLANG64) ARCH="x86_64"; ARCH_FLAG="x64compatible" ;;
  MINGW32|CLANG32)       ARCH="i686";   ARCH_FLAG="x86" ;;
  CLANGARM64)            ARCH="aarch64"; ARCH_FLAG="arm64" ;;
  *)
    echo "error: unsupported MSYSTEM type: $MSYSTEM"
    exit 1
    ;;
esac

if [ ! -x "$BUILD_DIR/lite-xl/aayushi-code$(get_executable_extension)" ]; then
  echo "Building portable tree..."
  scripts/build.sh --portable --builddir "$BUILD_DIR"
fi

mkdir -p dist
echo "==> Compiling Inno Setup installer..."

# INNOSETUP_ISS may point at a pre-configured .iss (created by meson on Windows)
ISS_FILE="${INNOSETUP_ISS:-$BUILD_DIR/scripts/innosetup.iss}"
if [ ! -f "$ISS_FILE" ]; then
  echo "Configured .iss not found at $ISS_FILE; need a meson-configured build."
  exit 1
fi

OUTPUT="$ROOT/dist/AayushiCode-$VERSION-$ARCH-windows-setup.exe"
# MSYS2 mangles leading-slash arguments (//O -> UNC paths), so disable
# argument conversion and hand ISCC native Windows paths instead.
mkdir -p "$ROOT/dist"
MSYS2_ARG_CONV_EXCL='*' \
  "$ISCC_EXE" -dArch=$ARCH_FLAG "/O$(cygpath -w "$ROOT/dist")" "$(cygpath -w "$ISS_FILE")"
echo "-> $OUTPUT"