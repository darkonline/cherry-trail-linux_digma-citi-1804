#!/bin/sh
# Builds hci_uart.ko with H5 + Realtek support for the running kernel.
# Run as the normal user (no sudo) from the folder that contains this script,
# the Makefile and the hci_*.c / *.h sources of the SAME kernel version.
# Re-run after every kernel update (sources must then match the new version).
set -eu
cd "$(dirname "$0")"
KVER="${KVER:-$(uname -r)}"
KDIR="/lib/modules/$KVER/build"

echo "Kernel: $KVER"
if [ ! -d "$KDIR" ]; then
	echo "ERROR: $KDIR not found. Install linux-lts-dev matching $KVER." >&2
	exit 1
fi
for f in hci_ldisc.c hci_h5.c hci_uart.h btrtl.h; do
	[ -f "$f" ] || { echo "ERROR: source file $f missing" >&2; exit 1; }
done

make clean >/dev/null 2>&1 || true
make KVER="$KVER" -j"$(nproc)"

echo
echo "== Result =="
ls -la hci_uart.ko
modinfo hci_uart.ko | grep -E "^(vermagic|depends|version):"
if modinfo hci_uart.ko | grep -q "acpi\*:OBDA8723:"; then
	echo "OK: module declares support for OBDA8723 (RTL8723BS Bluetooth)"
else
	echo "WARNING: OBDA8723 alias not found in the module" >&2
	exit 1
fi
