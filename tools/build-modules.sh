#!/bin/sh
# Digma CITI 1804: build the two out-of-tree kernel modules for every installed linux-lts kernel
# that does not have them yet:
#   hci_uart.ko          Bluetooth (stock driver + H5 and Realtek support, see bluetooth/)
#   intel_atomisp2_pm.ko deep sleep: powers the camera ISP down (see power-isp/)
# Installed to /usr/local/lib/citi1804/build-modules.sh with the sources next to it
# (modules-src/), and started by the apk hook /etc/apk/commit_hooks.d/citi1804-modules after
# every apk run, so a kernel update does not silently lose Bluetooth and deep sleep.
# Run as root. Options: --force (rebuild even if present), or kernel versions as arguments.
# Log: /var/log/citi1804-modules.log
set -u

SRC=/usr/local/lib/citi1804/modules-src
KORG="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain"
BT_FILES="btbcm.h btintel.h btqca.h btrtl.h hci_ag6xx.c hci_ath.c hci_bcm.c hci_bcsp.c hci_h4.c hci_h5.c hci_intel.c hci_ldisc.c hci_ll.c hci_qca.c hci_serdev.c hci_uart.h"
LOG=/var/log/citi1804-modules.log

FORCE=0
KVERS=""
for a in "$@"; do
	case "$a" in
	--force) FORCE=1 ;;
	*) KVERS="$KVERS $a" ;;
	esac
done
[ -n "$KVERS" ] || KVERS=$(ls /lib/modules 2>/dev/null | grep -- '-lts$')

log() { echo "citi1804-modules: $*" | tee -a "$LOG" >&2; }

# fetch <version> <tree path> <dir> <files...>: unmodified kernel sources of that version
fetch() {
	v=$1; p=$2; d=$3; shift 3
	for f in "$@"; do
		wget -q -O "$d/$f" "$KORG/$p/$f?h=v$v" || return 1
	done
}

build_one() {
	KVER=$1
	V=${KVER%%-*}
	KDIR=/lib/modules/$KVER/build
	UPD=/lib/modules/$KVER/updates

	if [ "$FORCE" = 0 ] && [ -f "$UPD/hci_uart.ko" ] && [ -f "$UPD/intel_atomisp2_pm.ko" ]; then
		return 0
	fi
	if [ ! -d "$KDIR" ]; then
		log "$KVER: no kernel headers ($KDIR); install linux-lts-dev, then run $0"
		return 1
	fi
	log "$KVER: building hci_uart and intel_atomisp2_pm"
	B=$(mktemp -d) || return 1
	mkdir -p "$B/bt" "$B/isp"
	cp "$SRC/bluetooth/Makefile" "$B/bt/" && cp "$SRC/power-isp/Makefile" "$B/isp/" || { rm -rf "$B"; return 1; }
	if [ "$V" = "$(cat "$SRC/VERSION" 2>/dev/null)" ]; then
		for f in $BT_FILES; do cp "$SRC/bluetooth/src/$f" "$B/bt/"; done
		cp "$SRC/power-isp/pm.c" "$B/isp/"
	else
		log "$KVER: downloading the v$V sources from git.kernel.org"
		# shellcheck disable=SC2086
		if ! fetch "$V" drivers/bluetooth "$B/bt" $BT_FILES ||
		   ! fetch "$V" drivers/platform/x86/intel/atomisp2 "$B/isp" pm.c; then
			log "$KVER: download failed (no network?); run $0 again later"
			rm -rf "$B"
			return 1
		fi
	fi
	ok=1
	make -C "$KDIR" M="$B/bt" modules >>"$LOG" 2>&1 || ok=0
	make -C "$KDIR" M="$B/isp" modules >>"$LOG" 2>&1 || ok=0
	if [ "$ok" = 1 ] && [ -f "$B/bt/hci_uart.ko" ] && [ -f "$B/isp/intel_atomisp2_pm.ko" ]; then
		install -D -m644 "$B/bt/hci_uart.ko" "$UPD/hci_uart.ko"
		install -D -m644 "$B/isp/intel_atomisp2_pm.ko" "$UPD/intel_atomisp2_pm.ko"
		depmod "$KVER"
		log "$KVER: done (active after reboot)"
	else
		log "$KVER: BUILD FAILED, see $LOG; Bluetooth and deep sleep will not work with this kernel"
		ok=0
	fi
	rm -rf "$B"
	[ "$ok" = 1 ]
}

rc=0
for k in $KVERS; do
	build_one "$k" || rc=1
done
exit $rc
