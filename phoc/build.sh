#!/bin/sh
# Build phoc with the "no modeset on rotation" patch, for the installed phoc version.
# Run as the normal user (no sudo). Build dependencies must be installed first (see README).
# Result: ~/.cache/phoc-fix/out/phoc-<version>; install it with: sudo sh install.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
VER=${PHOC_VERSION:-$(/usr/bin/phoc --version 2>/dev/null | sed -n 's/^Phoc \([0-9.]*\).*/\1/p')}
[ -n "$VER" ] || { echo "cannot detect the installed phoc version" >&2; exit 1; }

SUMS="$HERE/patches/phoc-$VER.sha512"
ls "$HERE"/patches/phoc-$VER-*.patch >/dev/null 2>&1 || { echo "no patches for phoc $VER" >&2; exit 1; }
[ -f "$SUMS" ] || { echo "no checksum for phoc $VER: $SUMS" >&2; exit 1; }

WORK=${WORK:-$HOME/.cache/phoc-fix}
DEST=$WORK/out
TARBALL=phoc-$VER.tar.xz
mkdir -p "$WORK"
cd "$WORK"

# libseat-dev cannot be installed on the systemd edition of postmarketOS (it pulls elogind-dev,
# which conflicts with systemd-dev). It only holds a header, a .so link and a .pc file, so unpack
# it locally (nothing is installed) and drop the elogind line from the .pc file.
if ! pkg-config --exists libseat; then
	echo "== libseat-dev: local copy (not installed)"
	S="$WORK/libseat"
	rm -rf "$S"; mkdir -p "$S/pkg"
	(cd "$S" && apk fetch -q -o . libseat-dev && tar -xzf libseat-dev-*.apk -C pkg 2>/dev/null)
	[ -f "$S/pkg/usr/include/libseat.h" ] || { echo "libseat-dev unpack failed" >&2; exit 1; }
	ln -sf /usr/lib/libseat.so.1 "$S/pkg/usr/lib/libseat.so"
	sed -e "s|^prefix=.*|prefix=$S/pkg/usr|" -e '/^Requires.private:/d' \
		"$S/pkg/usr/lib/pkgconfig/libseat.pc" > "$S/libseat.pc"
	export PKG_CONFIG_PATH="$S${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
	pkg-config --modversion libseat
fi

echo "== phoc $VER: download"
[ -f "$TARBALL" ] || wget -q -O "$TARBALL.part" "https://sources.phosh.mobi/releases/phoc/$TARBALL"
[ -f "$TARBALL.part" ] && mv "$TARBALL.part" "$TARBALL"
sha512sum -c "$SUMS"

echo "== unpack and patch"
rm -rf "phoc-$VER"
tar -xJf "$TARBALL"
cd "phoc-$VER"
# same as the Alpine package (APKBUILD prepare())
patch -Np1 -d subprojects/wlroots-0.20.x \
	< subprojects/packagefiles/wlroots/0001-Revert-layer-shell-error-on-0-dimension-without-anch.patch
for p in "$HERE"/patches/phoc-$VER-*.patch; do echo "patch: $p"; patch -Np1 < "$p"; done

echo "== configure (like the Alpine package, without LTO: 2 GB RAM)"
meson setup build \
	-Dbuildtype=release \
	-Db_lto=false \
	-Dembed-wlroots=enabled \
	-Dman=false \
	-Dtests=false \
	--default-library=static

echo "== compile (2 jobs)"
nice -n 10 meson compile -C build -j 2

install -D -m755 build/src/phoc "$DEST/phoc-$VER"
echo "done: $DEST/phoc-$VER  (now: sudo sh install.sh)"
