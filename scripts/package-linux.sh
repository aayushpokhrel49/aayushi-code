#!/usr/bin/env bash
# Builds Aayushi Code release packages for Linux: .deb, .rpm, Arch
# (.pkg.tar.zst), a portable tarball and (optionally) an AppImage.
#
# Usage:
#   ./scripts/package-linux.sh [deb] [rpm] [arch] [tar] [appimage]
#   (no arguments = build every packager available on this machine)
#
# Requires a built portable tree (default: build-x86_64-linux/lite-xl),
# which scripts/build.sh --portable produces. Artifacts land in dist/.
set -e

if [ ! -e "src/api/api.h" ]; then
  echo "Please run this script from the root directory of the repository."
  exit 1
fi

source scripts/common.sh

DIST_DIR="$(pwd -P)/dist"
WORK_DIR="$DIST_DIR/work"
BUILD_DIR="$(get_default_build_dir)"
PORTABLE_TREE="$BUILD_DIR/lite-xl"
VERSION="$(sed -n "s/^[[:space:]]*version : '\([^']*\)',/\1/p" meson.build | head -n 1)"
[ -n "$VERSION" ] || VERSION="0.0.0"
ARCH="$(get_platform_arch)"

case "$ARCH" in
  x86_64) DEB_ARCH="amd64" ;;
  aarch64|arm64) DEB_ARCH="arm64" ;;
  i686) DEB_ARCH="i386" ;;
  *) DEB_ARCH="$ARCH" ;;
esac

TARGETS="${*:-deb rpm arch tar}"
TARGETS="${TARGETS//, / }"

require_tree() {
  if [ ! -x "$PORTABLE_TREE/aayushi-code" ]; then
    echo "Portable tree not found at $PORTABLE_TREE."
    echo "Build it first with: scripts/build.sh --portable"
    exit 1
  fi
}

stage_system_tree() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$dest/usr/bin" "$dest/usr/share" "$dest/usr/share/doc"

  cp "$PORTABLE_TREE/bin/aayushi-code" "$dest/usr/bin/aayushi-code"

  rsync -a --delete "$PORTABLE_TREE/data/" "$dest/usr/share/aayushi-code/"
  if [ -d "$PORTABLE_TREE/doc" ]; then
    mkdir -p "$dest/usr/share/doc/aayushi-code"
    rsync -a "$PORTABLE_TREE/doc/" "$dest/usr/share/doc/aayushi-code/"
  fi

  install -D -m 0644 resources/icons/aayushi-code.svg \
    "$dest/usr/share/icons/hicolor/scalable/apps/aayushi-code.svg"
  install -D -m 0644 resources/linux/com.aayushi.code.desktop \
    "$dest/usr/share/applications/com.aayushi.code.desktop"

  if [ -f "$PORTABLE_TREE/share/metainfo/com.aayushi.code.metainfo.xml" ]; then
    install -D -m 0644 "$PORTABLE_TREE/share/metainfo/com.aayushi.code.metainfo.xml" \
      "$dest/usr/share/metainfo/com.aayushi.code.metainfo.xml"
  else
    install -D -m 0644 resources/linux/com.aayushi.code.metainfo.xml.in \
      "$dest/usr/share/metainfo/com.aayushi.code.metainfo.xml"
  fi

  # Normalize permissions: dirs 755, executables 755, everything else 644
  find "$dest/usr" -type d -exec chmod 755 {} +
  find "$dest/usr" -type f -perm /111 -exec chmod 755 {} +
  find "$dest/usr" -type f ! -perm /111 -exec chmod 644 {} +
}

make_tarball() {
  echo "==> Creating portable tarball..."
  mkdir -p "$DIST_DIR"
  tar -C "$BUILD_DIR/lite-xl" --exclude=share --exclude=bin -czf \
    "$DIST_DIR/aayushi-code-$VERSION-$ARCH-linux-portable.tar.gz" \
    aayushi-code data doc
}

make_deb() {
  command -v dpkg-deb >/dev/null || { echo "dpkg-deb not found, skipping .deb"; return 1; }
  echo "==> Creating Debian package..."
  local root="$WORK_DIR/deb-root"
  stage_system_tree "$root"

  local ctrl="$root/DEBIAN"
  mkdir -p "$ctrl"
  sed -e "s/@VERSION@/$VERSION/g" -e "s/@ARCH@/$DEB_ARCH/g" \
    packaging/debian/control.in > "$ctrl/control"
  cp packaging/debian/postinst "$ctrl/postinst"
  chmod 0755 "$ctrl/postinst"
  chmod 0644 "$ctrl/control"

  local deb="$DIST_DIR/aayushi-code_${VERSION}_${DEB_ARCH}.deb"
  dpkg-deb --build --root-owner-group "$root" "$deb"
  echo "   -> $deb"
}

make_rpm() {
  command -v rpmbuild >/dev/null || { echo "rpmbuild not found, skipping .rpm"; return 1; }
  echo "==> Creating RPM package..."
  local rpmdir="$WORK_DIR/rpmbuild"
  rm -rf "$rpmdir"
  mkdir -p "$rpmdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

  # Source tarball carrying the staged /usr tree
  local srcroot="$WORK_DIR/rpm-src"
  stage_system_tree "$srcroot"
  mkdir -p "$srcroot/aayushi-code-$VERSION"
  cp -a "$srcroot/usr" "$srcroot/aayushi-code-$VERSION/usr"
  tar -C "$srcroot" -czf "$rpmdir/SOURCES/aayushi-code-$VERSION.tar.gz" \
    "aayushi-code-$VERSION"

  sed "s/@VERSION@/$VERSION/g" packaging/aayushi-code.spec.in > "$rpmdir/SPECS/aayushi-code.spec"

  rpmbuild -bb --define "_topdir $rpmdir" --define "_rpmdir $WORK_DIR/RPMS" \
    --define "_builddir $rpmdir/BUILD" --define "_buildrootdir $rpmdir/BUILDROOT" \
    "$rpmdir/SPECS/aayushi-code.spec"
  find "$WORK_DIR/RPMS" -name '*.rpm' -exec mv -f {} "$DIST_DIR/" \;
  echo "   -> $DIST_DIR/aayushi-code-$VERSION-1.*.rpm"
}

make_arch() {
  command -v zstd >/dev/null || { echo "zstd not found, skipping Arch package"; return 1; }
  echo "==> Creating Arch Linux package..."
  local root="$WORK_DIR/arch-root"
  stage_system_tree "$root"

  local pkgver="${VERSION}-1"
  local pkg="$DIST_DIR/aayushi-code-$pkgver-$ARCH.pkg.tar.zst"

  # .PKGINFO (size is patched in after the archive is built)
  cat > "$root/.PKGINFO" <<EOF
pkgname = aayushi-code
pkgver = $pkgver
pkgdesc = A lightweight, ultra-fast code editor written in Lua, with bundled language servers
url = https://example.com/aayushi-code
builddate = $(date +%s)
packager = Aayushi Code Project <aayushi-code@example.com>
size = 0
arch = $ARCH
license = MIT
EOF

  # .MTREE (does not list itself or .PKGINFO, matching makepkg output)
  python3 - "$root" > "$root/.MTREE" <<'PYEOF'
import hashlib, os, stat, sys, time

root = os.path.abspath(sys.argv[1])
now = int(os.environ.get("SOURCE_DATE_EPOCH", "0") or "0")
now = now or int(time.time())
excluded = {".PKGINFO", ".MTREE"}


def fmt(rel, mode, size=0, sha=""):
    kind = "dir" if stat.S_ISDIR(mode) else "file"
    return "./{0} type={1} mode={2:o} uid=0 gid=0 time={3}.0 size={4} sha256digest={5}".format(
        rel, kind, stat.S_IMODE(mode), now, size, sha
    )

print("#mtree")
for dirpath, dirnames, filenames in os.walk(root):
    for name in dirnames + filenames:
        if name in excluded:
            continue
        p = os.path.join(dirpath, name)
        st = os.lstat(p)
        rel = os.path.relpath(p, root)
        if stat.S_ISREG(st.st_mode):
            sha = hashlib.sha256(open(p, "rb").read()).hexdigest()
            size = st.st_size
        else:
            sha, size = "", 0
        print(fmt(rel, st.st_mode, size, sha))
PYEOF

  # First pass: build the archive to measure its size
  tar -C "$root" --format=posix -cf - .PKGINFO .MTREE usr | zstd -q -3 --force -o "$pkg"
  local pkg_size
  pkg_size="$(stat -c%s "$pkg" 2>/dev/null || stat -f%z "$pkg")"

  # Second pass: patch the real size into .PKGINFO and rebuild
  sed -i "s/^size = 0$/size = $pkg_size/" "$root/.PKGINFO"
  tar -C "$root" --format=posix -cf - .PKGINFO .MTREE usr | zstd -q -3 --force -o "$pkg"
  echo "   -> $pkg"
}

make_appimage() {
  ./scripts/package-appimage.sh "$@"
}

mkdir -p "$DIST_DIR" "$WORK_DIR"
require_tree

do_log=""
for target in $TARGETS; do
  case "$target" in
    tar) make_tarball || true ;;
    deb) make_deb || true ;;
    rpm) make_rpm || true ;;
    arch) make_arch || true ;;
    appimage) make_appimage || true ;;
    *) echo "Unknown target: $target (choices: deb rpm arch tar appimage)" ;;
  esac
done

echo
echo "Packages written to: $DIST_DIR"
ls -lh "$DIST_DIR" | grep -v "^total" || true