#!/bin/sh
# Digma CITI 1804: DISABLE the cameras and restore deep sleep (intel_atomisp2_pm). This is the default state.
# Run as the NORMAL user (it asks for the sudo password):   sh ~/digma-citi1804-linux/camera/disable.sh
# The ISP firmware in /lib/firmware stays; without the atomisp driver it is never used.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
KVER=$(ls /lib/modules | grep -- '-lts$' | sort -V | tail -n1); V=${KVER%%-*}
U=/lib/modules/$KVER/updates
KORG="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain"
[ "$(id -u)" != 0 ] || { echo "Run as the normal user, not with sudo." >&2; exit 1; }

echo "== 1. Remove the camera modules"
sudo rm -f "$U/ipu-bridge.ko" "$U/ov2680.ko" "$U/gc0310.ko" "$U/atomisp.ko" "$U/atomisp_gmin_platform.ko"
sudo rmmod eldo2_on 2>/dev/null || true

echo "== 2. Build and install the deep-sleep module for $KVER"
B=$(mktemp -d); trap 'rm -rf "$B"' EXIT
cp "$REPO/power-isp/Makefile" "$B/"
if [ "$V" = 6.18.63 ]; then cp "$REPO/power-isp/pm.c" "$B/"
else wget -q -O "$B/pm.c" "$KORG/drivers/platform/x86/intel/atomisp2/pm.c?h=v$V"; fi
(cd "$B" && make KVER="$KVER" >/dev/null)
sudo install -D -m644 "$B/intel_atomisp2_pm.ko" "$U/intel_atomisp2_pm.ko"
sudo depmod "$KVER"
echo "Done. Reboot: sudo reboot"
echo "Check afterwards: the camera ISP must be in D3cold:  cat /sys/bus/pci/devices/0000:00:03.0/power_state"
