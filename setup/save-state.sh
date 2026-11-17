#!/bin/sh
# Digma CITI 1804: saves the current hardware-related configuration of THIS tablet into one archive,
# laid out like this repository, so the repository can be updated from it (or compared with it).
# Run as the normal user, no sudo:   sh save-state.sh      ->  ~/citi1804-state-<date>.tar.gz
# Contains no app data, no Wi-Fi passwords, no Bluetooth pairings, no keys.
set -eu
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
O="$T/state"; mkdir -p "$O"

copy() { # copy <source> <dest relative to state/>
	[ -e "$1" ] || { echo "missing: $1"; return 0; }
	mkdir -p "$O/$(dirname "$2")"; cp "$1" "$O/$2"
}
copy /lib/firmware/silead/mssl1680.fw                     firmware/silead/mssl1680.fw
for f in /etc/kernel-cmdline.d/*.conf; do copy "$f" "config/etc/kernel-cmdline.d/$(basename "$f")"; done
copy /etc/mkinitfs/modules/00-citi1804.modules            config/etc/mkinitfs/modules/00-citi1804.modules
copy /etc/phosh/phoc.ini                                  config/etc/phosh/phoc.ini
copy /etc/environment                                     config/etc/environment
copy "$HOME/.config/pulse/default.pa"                     config/home/.config/pulse/default.pa
copy "$HOME/.local/bin/jack-profile-switch.sh"            config/home/.local/bin/jack-profile-switch.sh
copy "$HOME/.config/systemd/user/jack-profile-switch.service" config/home/.config/systemd/user/jack-profile-switch.service
copy "$HOME/.config/mpv/mpv.conf"                         config/home/.config/mpv/mpv.conf
copy "$HOME/.local/share/applications/de.schmidhuberj.tubefeeder.desktop" config/home/.local/share/applications/de.schmidhuberj.tubefeeder.desktop
for p in "$HOME"/.mozilla/firefox/*.default-release/user.js; do copy "$p" config/home/firefox/user.js; done
mkdir -p "$O/setup"
grep -vxE 'acpica|iasl' /etc/apk/world > "$O/setup/apk-world.txt"
flatpak list --app --columns=application > "$O/setup/flatpak-apps.txt" 2>/dev/null || true
{
	echo "# saved $(date '+%F %T') on $(hostname)"
	echo "kernel: $(uname -r)"
	echo "cmdline: $(cat /proc/cmdline)"
	echo "updates modules: $(ls /lib/modules/$(uname -r)/updates 2>/dev/null | tr '\n' ' ')"
	echo "power-button-action: $(gsettings get org.gnome.settings-daemon.plugins.power power-button-action 2>/dev/null)"
	echo "screen-keyboard-enabled: $(gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled 2>/dev/null)"
	echo "jack-profile-switch: $(systemctl --user is-enabled jack-profile-switch 2>/dev/null)"
	echo "masked user units: $(systemctl --user list-unit-files --state=masked --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
	echo "ModemManager: $(systemctl is-enabled ModemManager 2>/dev/null)"
} > "$O/setup/state-info.txt"
out="$HOME/citi1804-state-$(date +%Y%m%d).tar.gz"
tar -czf "$out" -C "$T" state
ls -la "$out"
