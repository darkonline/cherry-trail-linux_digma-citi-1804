#!/bin/sh
# Digma CITI 1804: applies the hardware setup of this repository to a fresh postmarketOS (Phosh) install,
# then OFFERS optional app groups one by one (each asked separately, default = no).
#
# Run as the NORMAL user (not with sudo) in the Console app on the tablet:
#     sh ~/digma-citi1804-linux/setup/restore.sh
# It asks for your password when a step needs sudo. Safe to run again (every step is idempotent).
# Options:  --check     only print what would be done, change nothing
#           --no-apps   hardware setup only, do not ask about apps
#           --all-apps  install every app group without asking
#
# Hardware part (always):
#   1. apk update/upgrade (needed so the kernel headers match the kernel), build tools
#   2. touchscreen firmware + kernel parameters (touch, audio quirk, SST audio driver), initramfs modules, cursor, 150 % scale
#   3. removes phone apps (no modem in this tablet), disables ModemManager
#   4. builds and installs hci_uart.ko (Bluetooth) and intel_atomisp2_pm.ko (deep sleep) for the installed kernel
#   5. mkinitfs
#   6. user settings: PulseAudio tsched=0, speaker/headphone switcher, power button, on-screen keyboard,
#      background cleanup
# Optional app groups (asked one by one): see section 7.
# The cameras are NOT touched (disabled by default, see camera/README.md). Then reboot.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
CHECK=0; APPS=ask
for a in "$@"; do
	case "$a" in
	--check) CHECK=1 ;;
	--no-apps) APPS=none ;;
	--all-apps) APPS=all ;;
	*) echo "unknown option: $a" >&2; exit 1 ;;
	esac
done
[ "$(id -u)" != 0 ] || { echo "Run as the normal user, not with sudo." >&2; exit 1; }

say() { printf '\n==== %s\n' "$*"; }
run() { if [ "$CHECK" = 1 ]; then echo "[check] $*"; else "$@"; fi; }
KORG="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain"
H="$REPO/config/home"

# ask "<question>" -> 0 for yes. Default is no. Without a terminal (or --no-apps) the answer is no.
ask() {
	case "$APPS" in all) return 0 ;; none) return 1 ;; esac
	[ -r /dev/tty ] || return 1
	printf '\n%s [y/N] ' "$1" >/dev/tty
	read -r reply </dev/tty || return 1
	case "$reply" in y|Y|yes|д|Д|да|Да) return 0 ;; *) return 1 ;; esac
}

# newest installed kernel (after an upgrade this is the one that will boot next)
installed_kver() { ls /lib/modules | grep -- '-lts$' | sort -V | tail -n1; }

# fetch_src <kernel-version> <tree-path> <dest-dir> <files...> : download unmodified kernel source files
fetch_src() {
	v=$1; p=$2; d=$3; shift 3
	for f in "$@"; do
		wget -q -O "$d/$f" "$KORG/$p/$f?h=v$v" || { echo "download failed: $p/$f (v$v)" >&2; return 1; }
	done
}

# ================================================================ HARDWARE
say "1. System update and build tools"
run sudo apk update
run sudo apk upgrade
run sudo apk add linux-lts-dev build-base rsync efibootmgr parted dosfstools e2fsprogs wget
KVER=$(installed_kver); V=${KVER%%-*}
echo "kernel for the modules: $KVER (running: $(uname -r))"

say "2. Touchscreen, audio, backlight, cursor, scale"
run sudo install -D -m644 "$REPO/firmware/silead/mssl1680.fw" /lib/firmware/silead/mssl1680.fw
run sudo install -D -m644 -t /etc/kernel-cmdline.d "$REPO"/config/etc/kernel-cmdline.d/*.conf
run sudo install -D -m644 -t /etc/mkinitfs/modules "$REPO/config/etc/mkinitfs/modules/00-citi1804.modules"
run sudo install -D -m644 "$REPO/config/etc/phosh/phoc.ini" /etc/phosh/phoc.ini
if ! grep -q '^WLR_NO_HARDWARE_CURSORS=1' /etc/environment 2>/dev/null; then
	if [ "$CHECK" = 1 ]; then echo "[check] add WLR_NO_HARDWARE_CURSORS=1 to /etc/environment"
	else echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment >/dev/null; fi
fi

say "3. Phone apps and ModemManager"
if apk info -e calls >/dev/null 2>&1 || apk info -e chatty >/dev/null 2>&1; then
	run sudo sh "$REPO/tools/bg-system.sh" || echo "(bg-system.sh reported an error, continuing)"
else
	run sudo systemctl disable --now ModemManager.service || true
	echo "phone apps already removed"
fi

say "4. Bluetooth (hci_uart) and deep sleep (intel_atomisp2_pm) for $KVER"
if [ "$CHECK" = 1 ]; then
	if [ "$V" = 6.18.63 ]; then echo "[check] bundled 6.18.63 sources will be used"
	else echo "[check] sources v$V will be downloaded from git.kernel.org"; fi
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

say "5. mkinitfs (applies kernel parameters and initramfs modules)"
run sudo mkinitfs

say "6. User settings"
run install -D -m644 "$H/.config/pulse/default.pa" "$HOME/.config/pulse/default.pa"
run install -D -m755 "$H/.local/bin/jack-profile-switch.sh" "$HOME/.local/bin/jack-profile-switch.sh"
run install -D -m644 "$H/.config/systemd/user/jack-profile-switch.service" "$HOME/.config/systemd/user/jack-profile-switch.service"
run install -D -m755 "$REPO/tools/battery-log.sh" "$HOME/.local/bin/battery-log.sh"
run systemctl --user daemon-reload
run systemctl --user enable jack-profile-switch.service
run gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
run gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
run sh "$REPO/tools/bg-user.sh"
run systemctl --user mask gnome-software.service || true

say "Hardware setup done."

# ================================================================ 7. OPTIONAL APPS (asked one by one)
if [ "$APPS" != none ]; then
	say "7. Optional apps (each is asked separately; Enter = no)"

	if ask "Office: LibreOffice (~540 MB)?"; then
		run sudo apk add libreoffice
	fi

	if ask "Utilities: 7-Zip, archive manager, task manager (Resources), screenshots?"; then
		run sudo apk add 7zip file-roller resources gnome-screenshot
	fi

	if ask "YouTube without a browser: Pipeline + mpv with hardware video decoding?"; then
		run sudo apk add pipeline mpv yt-dlp clapper libpeas2-python3
		[ -e /usr/lib/libgstclapper.so ] || run sudo ln -s /usr/lib/gstreamer-1.0/libgstclapper.so /usr/lib/libgstclapper.so
		run install -D -m644 "$H/.local/share/applications/de.schmidhuberj.tubefeeder.desktop" \
			"$HOME/.local/share/applications/de.schmidhuberj.tubefeeder.desktop"
		run install -D -m644 "$H/.config/mpv/mpv.conf" "$HOME/.config/mpv/mpv.conf"
	fi

	if ask "Firefox: hardware video decoding settings (start Firefox once before, so its profile exists)?"; then
		found=0
		for p in "$HOME"/.mozilla/firefox/*.default-release; do
			[ -d "$p" ] || continue
			run install -m644 "$H/firefox/user.js" "$p/user.js"; echo "Firefox: $p"; found=1
		done
		[ "$found" = 1 ] || echo "No Firefox profile yet: start Firefox once, then run this script again."
	fi

	flathub_ready=0
	flathub() {
		if [ "$flathub_ready" = 0 ]; then
			run sudo apk add flatpak
			run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
			flathub_ready=1
		fi
		run sudo flatpak install -y --noninteractive flathub "$1"
	}
	if ask "Telegram (Flathub; the Alpine package is broken)?"; then
		flathub org.telegram.desktop
	fi
	if ask "Spotify (Flathub, with the sound fix)?"; then
		flathub com.spotify.Client
		run flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client
	fi
fi

say "Done. Reboot now: sudo reboot"
echo "Afterwards: touch, backlight, speaker/headphones, Bluetooth and deep sleep should work."
echo "To move the system to the internal eMMC (erases it): sudo sh $REPO/install/install-emmc.sh"
