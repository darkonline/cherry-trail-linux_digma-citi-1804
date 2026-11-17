#!/bin/sh
# Digma CITI 1804: applies the whole hardware setup of this repository to a fresh postmarketOS (Phosh) install.
#
# Run as the NORMAL user (not with sudo) in the Console app on the tablet, from any folder:
#     sh ~/digma-citi1804-linux/setup/restore.sh
# It asks for your password when a step needs sudo. Safe to run again (every step is idempotent).
# Options:  --check   only print what would be done and the detected kernel, change nothing
#           --no-apps skip installing the app packages and Flathub apps (hardware setup only)
#
# What it does:
#   1. apk update/upgrade, build tools, (optionally) the app packages from setup/apk-world.txt
#   2. touchscreen firmware + kernel parameters (touch, audio quirk), initramfs modules, cursor, 150 % scale
#   3. removes phone apps, disables ModemManager (tools/bg-system.sh)
#   4. builds and installs hci_uart.ko (Bluetooth) and intel_atomisp2_pm.ko (deep sleep) for the installed kernel
#   5. mkinitfs
#   6. user settings: PulseAudio tsched=0, speaker/headphone switcher, power button, background cleanup,
#      Firefox video settings, Pipeline (YouTube) fixes
#   7. (optionally) Flathub apps + Spotify sound fix
# Then reboot.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
CHECK=0; APPS=1
for a in "$@"; do
	case "$a" in
	--check) CHECK=1 ;;
	--no-apps) APPS=0 ;;
	*) echo "unknown option: $a" >&2; exit 1 ;;
	esac
done
[ "$(id -u)" != 0 ] || { echo "Run as the normal user, not with sudo." >&2; exit 1; }

say() { printf '\n==== %s\n' "$*"; }
run() { if [ "$CHECK" = 1 ]; then echo "[check] $*"; else "$@"; fi; }
KORG="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain"

# newest installed kernel (after an upgrade this is the one that will boot next)
installed_kver() { ls /lib/modules | grep -- '-lts$' | sort -V | tail -n1; }

# fetch_src <kernel-version> <tree-path> <dest-dir> <files...> : download unmodified kernel source files
fetch_src() {
	v=$1; p=$2; d=$3; shift 3
	for f in "$@"; do
		wget -q -O "$d/$f" "$KORG/$p/$f?h=v$v" || { echo "download failed: $p/$f (v$v)" >&2; return 1; }
	done
}

# ---------------------------------------------------------------- 1. packages
say "1. Packages"
run sudo apk update
run sudo apk upgrade
run sudo apk add linux-lts-dev build-base rsync efibootmgr parted dosfstools e2fsprogs wget
if [ "$APPS" = 1 ]; then
	# shellcheck disable=SC2046
	run sudo apk add $(grep -v '^#' "$REPO/setup/apk-world.txt")
fi
KVER=$(installed_kver); V=${KVER%%-*}
echo "kernel for the modules: $KVER (running: $(uname -r))"

# ---------------------------------------------------------------- 2. system configuration
say "2. Touchscreen, audio, backlight, cursor, scale"
run sudo install -D -m644 "$REPO/firmware/silead/mssl1680.fw" /lib/firmware/silead/mssl1680.fw
run sudo install -D -m644 -t /etc/kernel-cmdline.d "$REPO"/config/etc/kernel-cmdline.d/*.conf
run sudo install -D -m644 -t /etc/mkinitfs/modules "$REPO/config/etc/mkinitfs/modules/00-citi1804.modules"
run sudo install -D -m644 "$REPO/config/etc/phosh/phoc.ini" /etc/phosh/phoc.ini
if ! grep -q '^WLR_NO_HARDWARE_CURSORS=1' /etc/environment 2>/dev/null; then
	if [ "$CHECK" = 1 ]; then echo "[check] add WLR_NO_HARDWARE_CURSORS=1 to /etc/environment"
	else echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment >/dev/null; fi
fi

# ---------------------------------------------------------------- 3. phone apps / modem
say "3. Phone apps and ModemManager"
if apk info -e calls >/dev/null 2>&1 || apk info -e chatty >/dev/null 2>&1; then
	run sudo sh "$REPO/tools/bg-system.sh" || echo "(bg-system.sh reported an error, continuing)"
else
	run sudo systemctl disable --now ModemManager.service || true
	echo "phone apps already removed"
fi

# ---------------------------------------------------------------- 4. kernel modules
say "4. Bluetooth (hci_uart) and deep sleep (intel_atomisp2_pm) for $KVER"
if [ "$CHECK" = 1 ]; then
	[ "$V" = 6.18.63 ] && echo "[check] bundled 6.18.63 sources will be used" || echo "[check] sources v$V will be downloaded from git.kernel.org"
else
	B=$(mktemp -d); trap 'rm -rf "$B"' EXIT
	mkdir -p "$B/bt" "$B/isp"
	cp "$REPO/bluetooth/Makefile" "$REPO/bluetooth/build-bt.sh" "$B/bt/"
	cp "$REPO/power-isp/Makefile" "$B/isp/"
	BT_FILES="btbcm.h btintel.h btqca.h btrtl.h hci_ag6xx.c hci_ath.c hci_bcm.c hci_bcsp.c hci_h4.c hci_h5.c hci_intel.c hci_ldisc.c hci_ll.c hci_qca.c hci_serdev.c hci_uart.h"
	if [ "$V" = 6.18.63 ]; then
		for f in $BT_FILES; do cp "$REPO/bluetooth/src/$f" "$B/bt/"; done
		cp "$REPO/power-isp/pm.c" "$B/isp/"
	else
		echo "kernel $V differs from the bundled 6.18.63 sources: downloading v$V from git.kernel.org"
		# shellcheck disable=SC2086
		fetch_src "$V" drivers/bluetooth "$B/bt" $BT_FILES
		fetch_src "$V" drivers/platform/x86/intel/atomisp2 "$B/isp" pm.c
	fi
	(cd "$B/bt" && KVER="$KVER" sh build-bt.sh)
	(cd "$B/isp" && make KVER="$KVER" >/dev/null && ls -la intel_atomisp2_pm.ko)
	sudo install -D -m644 "$B/bt/hci_uart.ko" "/lib/modules/$KVER/updates/hci_uart.ko"
	sudo install -D -m644 "$B/isp/intel_atomisp2_pm.ko" "/lib/modules/$KVER/updates/intel_atomisp2_pm.ko"
	sudo depmod "$KVER"
fi

# ---------------------------------------------------------------- 5. initramfs + boot entry
say "5. mkinitfs (applies kernel parameters and initramfs modules)"
run sudo mkinitfs

# ---------------------------------------------------------------- 6. user settings
say "6. User settings"
H="$REPO/config/home"
run install -D -m644 "$H/.config/pulse/default.pa" "$HOME/.config/pulse/default.pa"
run install -D -m755 "$H/.local/bin/jack-profile-switch.sh" "$HOME/.local/bin/jack-profile-switch.sh"
run install -D -m644 "$H/.config/systemd/user/jack-profile-switch.service" "$HOME/.config/systemd/user/jack-profile-switch.service"
run install -D -m644 "$H/.config/mpv/mpv.conf" "$HOME/.config/mpv/mpv.conf"
run install -D -m755 "$REPO/tools/battery-log.sh" "$HOME/.local/bin/battery-log.sh"
run systemctl --user daemon-reload
run systemctl --user enable jack-profile-switch.service
run gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
run gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
run sh "$REPO/tools/bg-user.sh"
run systemctl --user mask gnome-software.service || true
# Firefox: only if a profile already exists (start Firefox once first)
for p in "$HOME"/.mozilla/firefox/*.default-release; do
	[ -d "$p" ] && run install -m644 "$H/firefox/user.js" "$p/user.js" && echo "Firefox: $p"
done
# Pipeline (YouTube) fixes, only if installed
if [ -x /usr/bin/tubefeeder ]; then
	[ -e /usr/lib/libgstclapper.so ] || run sudo ln -s /usr/lib/gstreamer-1.0/libgstclapper.so /usr/lib/libgstclapper.so
	run install -D -m644 "$H/.local/share/applications/de.schmidhuberj.tubefeeder.desktop" \
		"$HOME/.local/share/applications/de.schmidhuberj.tubefeeder.desktop"
fi

# ---------------------------------------------------------------- 7. Flathub apps
if [ "$APPS" = 1 ]; then
	say "7. Flathub apps"
	run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	for app in $(cat "$REPO/setup/flatpak-apps.txt"); do run sudo flatpak install -y --noninteractive flathub "$app"; done
	run flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client
fi

say "Done. Reboot now: sudo reboot"
echo "Afterwards: touch, backlight, speaker/headphones, Bluetooth and deep sleep should work."
echo "To move the system to the internal eMMC (erases it): sudo sh $REPO/install/install-emmc.sh"
