#!/bin/sh
# Return to the stock phoc and remove the wallpaper sync. Run with sudo. Takes effect after a reboot.
# /etc/citi1804/phoc.env and /var/lib/citi1804 are kept (delete them by hand if you want).
set -eu
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
U=${SUDO_USER:-}
if [ -n "$U" ]; then
	UHOME=$(getent passwd "$U" | cut -d: -f6)
	if [ -f "$UHOME/.phoshdebug" ] && grep -q 'citi1804' "$UHOME/.phoshdebug"; then
		rm -f "$UHOME/.phoshdebug"
		echo "removed $UHOME/.phoshdebug"
	fi
fi
rm -f /usr/local/bin/phosh-session
systemctl --global disable citi1804-wallpaper.path citi1804-wallpaper.service 2>/dev/null || true
rm -f /etc/systemd/user/citi1804-wallpaper.path /etc/systemd/user/citi1804-wallpaper.service
rm -f /usr/share/glib-2.0/schemas/90-citi1804.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas
rm -rf /usr/local/lib/citi1804/phoc /usr/local/lib/citi1804/wallpaper-sync.py /usr/local/share/citi1804/shield.png
echo "removed. The login screen falls back to /usr/bin/phoc by itself. Reboot."
