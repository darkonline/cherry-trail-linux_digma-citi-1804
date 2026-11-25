#!/bin/sh
# Install the patched phoc built by build.sh, for the user session and the login screen (phrog),
# plus the wallpaper sync. Run with sudo:  sudo sh install.sh        Undo: sudo sh uninstall.sh
# Files (nothing from a package is changed):
#   /usr/local/lib/citi1804/phoc/phoc-<version>   patched binary
#   /usr/local/lib/citi1804/phoc/phoc             wrapper ("phoc", so phrog finds it via PATH):
#       - reads the settings in /etc/citi1804/phoc.env
#       - uses the patched binary only while its version equals /usr/bin/phoc
#         (after an OS update to another phoc version the stock phoc is used automatically)
#       - if the patched phoc exits with an error within 15 s, starts the stock phoc instead
#   /etc/citi1804/phoc.env                        settings (edit with sudo, apply by logging in again)
#   /usr/local/lib/citi1804/wallpaper-sync.py     wallpaper -> /var/lib/citi1804/wallpaper.png
#   /etc/systemd/user/citi1804-wallpaper.{path,service}  run it when the settings change
#   /usr/share/glib-2.0/schemas/90-citi1804.gschema.override  login screen wallpaper
#   /usr/local/bin/phosh-session                  Phosh session start with the wrapper (found via PATH)
# The login screen gets the wrapper through PATH in /etc/greetd/citi1804-phrog.toml
# (tools/boot-polish.sh of the main repository).
set -eu
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
U=${SUDO_USER:-}
[ -n "$U" ] && [ "$U" != root ] || { echo "run with sudo from your normal user" >&2; exit 1; }
UHOME=$(getent passwd "$U" | cut -d: -f6)
UID_=$(id -u "$U")
HERE=$(cd "$(dirname "$0")" && pwd)
asuser() { sudo -u "$U" XDG_RUNTIME_DIR=/run/user/$UID_ DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_/bus "$@"; }

VER=$(/usr/bin/phoc --version 2>/dev/null | sed -n 's/^Phoc \([0-9.]*\).*/\1/p')
BUILT=$UHOME/.cache/phoc-fix/out/phoc-$VER
[ -x "$BUILT" ] || { echo "no patched phoc $VER: run build.sh first ($BUILT)" >&2; exit 1; }

echo "== patched phoc $VER and wrapper"
D=/usr/local/lib/citi1804/phoc
install -D -m755 "$BUILT" "$D/phoc-$VER"
cat > "$D/phoc" <<'EOF'
#!/bin/sh
# citi1804 phoc wrapper (see phoc-fix/install.sh)
STOCK=/usr/bin/phoc
D=/usr/local/lib/citi1804/phoc
if [ -r /etc/citi1804/phoc.env ]; then set -a; . /etc/citi1804/phoc.env; set +a; fi
# boot splash still up (first start after boot): ask it to hand the display over now, so the
# logo keeps spinning until this moment (tools/boot-polish.sh of the main repository)
if pidof plymouthd >/dev/null 2>&1 && [ -d /run/citi1804 ]; then
	: > /run/citi1804/plymouth-deactivate 2>/dev/null
	i=0
	while [ ! -e /run/citi1804/plymouth-deactivated ] && [ $i -lt 30 ]; do sleep 0.1; i=$((i+1)); done
fi
VER=$("$STOCK" --version 2>/dev/null | sed -n 's/^Phoc \([0-9.]*\).*/\1/p')
PATCHED=$D/phoc-$VER
if [ -n "$VER" ] && [ -x "$PATCHED" ]; then
	start=$(date +%s)
	"$PATCHED" "$@"
	rc=$?
	if [ "$rc" -ne 0 ] && [ $(( $(date +%s) - start )) -lt 15 ]; then
		echo "citi1804: patched phoc $VER failed (exit $rc), starting the stock phoc" >&2
		exec "$STOCK" "$@"
	fi
	exit "$rc"
fi
exec "$STOCK" "$@"
EOF
chmod 755 "$D/phoc"

# settings file; rewritten only if it is missing or from an older version of this script
if ! grep -q '^# citi1804 phoc.env v5' /etc/citi1804/phoc.env 2>/dev/null; then
	[ -e /etc/citi1804/phoc.env ] && cp /etc/citi1804/phoc.env /etc/citi1804/phoc.env.old
	install -D -m644 /dev/null /etc/citi1804/phoc.env
	cat > /etc/citi1804/phoc.env <<'EOF'
# citi1804 phoc.env v5
# Settings of the patched phoc. Edit with sudo; applied at the next login or reboot.
#
# Startup screen (while the session starts): the postmarketOS boot logo, spinning like the boot
# splash, on black. Empty = the spinner of stock phoc.
PHOC_SHIELD_LOGO_DIR=/usr/share/plymouth/themes/pmos-spin
# Picture behind it (e.g. /var/lib/citi1804/wallpaper.png = the wallpaper from Settings, kept up
# to date automatically). Empty = black.
PHOC_SHIELD_IMAGE=
# How much to darken that picture: 0 = not at all, 1 = black
PHOC_SHIELD_DIM=0.4
# Fade-out of the startup screen when the desktop or lock screen is ready, in ms (0 = cut)
PHOC_SHIELD_FADE_MS=400
# Screen rotation. 1 = the last frame (turned upright for the new orientation) recedes (shrinks
# to 85 % and dims), stays while the panels rearrange, then the new layout fades in
PHOC_ROTATE_SNAPSHOT=1
# Recede time, fade-in time of the new layout, and the longest the old frame is kept if the
# panels are slow, all in ms
PHOC_ROTATE_RECEDE_MS=250
PHOC_ROTATE_FADE_MS=400
PHOC_ROTATE_SNAPSHOT_MAX_MS=2500
# Without the snapshot: 1 = no black screen while the panels rearrange (they are seen
# rearranging for a moment); 0 = black, as in stock phoc
PHOC_NO_TRANSFORM_SHIELD=1
EOF
fi

echo "== wallpaper sync"
install -d -m755 -o "$U" /var/lib/citi1804
install -D -m755 "$HERE/wallpaper-sync.py" /usr/local/lib/citi1804/wallpaper-sync.py
mkdir -p /etc/systemd/user
cat > /etc/systemd/user/citi1804-wallpaper.service <<'EOF'
[Unit]
Description=Copy the wallpaper for the login and startup screens (citi1804)
ConditionUser=!greetd

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/lib/citi1804/wallpaper-sync.py

[Install]
WantedBy=default.target
EOF
cat > /etc/systemd/user/citi1804-wallpaper.path <<'EOF'
[Unit]
Description=Watch the settings for a new wallpaper (citi1804)
ConditionUser=!greetd

[Path]
PathChanged=%h/.config/dconf/user
Unit=citi1804-wallpaper.service

[Install]
WantedBy=default.target
EOF
systemctl --global enable citi1804-wallpaper.path citi1804-wallpaper.service
# keep the user's own wallpaper as an explicit setting, so the new default below only affects
# the login screen user
for k in picture-uri picture-uri-dark; do
	v=$(asuser gsettings get org.gnome.desktop.background $k 2>/dev/null || true)
	[ -n "$v" ] && asuser gsettings set org.gnome.desktop.background $k "$v" || true
done
asuser python3 /usr/local/lib/citi1804/wallpaper-sync.py || echo "wallpaper sync failed (see above)" >&2
cat > /usr/share/glib-2.0/schemas/90-citi1804.gschema.override <<'EOF'
# citi1804: the login screen (user greetd) shows the wallpaper of the main user
[org.gnome.desktop.background]
picture-uri='file:///var/lib/citi1804/wallpaper.png'
picture-uri-dark='file:///var/lib/citi1804/wallpaper.png'

[org.gnome.desktop.screensaver]
picture-uri='file:///var/lib/citi1804/wallpaper.png'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas
rm -f /usr/local/share/citi1804/shield.png  # from the first version of this script

echo "== Phosh session"
# phrog starts the session as "phosh-session" through PATH, and /usr/local/bin comes before
# /usr/bin there. This copy starts phoc through the wrapper; /usr/bin/phosh-session can only
# be redirected with ~/.phoshdebug, which also prints "WARN: .phoshdebug found." on the screen.
cat > /usr/local/bin/phosh-session <<'EOF'
#!/bin/sh
# citi1804: like /usr/bin/phosh-session (phosh 0.55), but phoc is started through the citi1804
# wrapper. Falls back to the stock script if the wrapper is missing or for --help/--version.
W=/usr/local/lib/citi1804/phoc/phoc
if [ ! -x "$W" ] || [ $# -gt 0 ]; then
	exec /usr/bin/phosh-session "$@"
fi
PHOC_INI=/usr/share/phosh/phoc.ini
[ -f /etc/phosh/phoc.ini ] && PHOC_INI=/etc/phosh/phoc.ini
PHOSH_SESSION_BIN=${PHOSH_SESSION_BIN:-gnome-session}
SYSTEMD_CAT=
command -v systemd-cat >/dev/null 2>&1 && SYSTEMD_CAT="systemd-cat -t phoc"
DBUS_RUN_SESSION=
[ -z "$DBUS_SESSION_BUS_ADDRESS" ] && DBUS_RUN_SESSION="dbus-run-session --"
[ -n "$WLR_BACKENDS" ] || WLR_BACKENDS=drm,libinput
export WLR_BACKENDS
exec $SYSTEMD_CAT $DBUS_RUN_SESSION "$W" -v -S -C "$PHOC_INI" -E "$PHOSH_SESSION_BIN --session=phosh"
EOF
chmod 755 /usr/local/bin/phosh-session
# the first version of this script used ~/.phoshdebug; remove ours
if [ -f "$UHOME/.phoshdebug" ] && grep -q 'citi1804' "$UHOME/.phoshdebug"; then
	rm -f "$UHOME/.phoshdebug"
fi
echo "installed. Reboot to use it."
