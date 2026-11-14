#!/bin/sh
# User-level (no sudo): stop background components that are not needed on this tablet.
# Undo: rm the files in ~/.config/autostart listed below; systemctl --user unmask <unit>;
#       gsettings reset org.gnome.software download-updates; gsettings reset org.gnome.software allow-updates
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
mkdir -p ~/.config/autostart
for f in udiskie.desktop localsearch-3.desktop; do
	if [ -f "/etc/xdg/autostart/$f" ]; then
		{ cat "/etc/xdg/autostart/$f"; echo "Hidden=true"; } > ~/.config/autostart/$f
		echo "autostart hidden: $f"
	fi
done
for u in udiskie.service cellbroadcastd.service localsearch-3.service; do
	if systemctl --user cat "$u" >/dev/null 2>&1; then
		systemctl --user stop "$u" 2>/dev/null
		systemctl --user mask "$u" >/dev/null 2>&1 && echo "masked: $u"
	fi
done
pkill -u "$(id -u)" -x udiskie 2>/dev/null; pkill -u "$(id -u)" -f '/usr/bin/udiskie' 2>/dev/null
# GNOME Software: no automatic update downloads in the background
gsettings set org.gnome.software download-updates false 2>/dev/null && echo "gnome-software: download-updates=false"
gsettings set org.gnome.software allow-updates false 2>/dev/null && echo "gnome-software: allow-updates=false"
echo "done"
