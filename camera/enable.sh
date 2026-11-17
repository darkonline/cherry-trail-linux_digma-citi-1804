#!/bin/sh
# Digma CITI 1804: ENABLE the cameras (atomisp + ov2680 + gc0310).
# Run as the NORMAL user (it asks for the sudo password):   sh ~/digma-citi1804-linux/camera/enable.sh
#
# !!! While the cameras are enabled, deep sleep does NOT work: the deep-sleep module intel_atomisp2_pm and the
# !!! camera driver atomisp use the same device (the camera ISP), so the module is removed. Battery drain in
# !!! suspend goes up from deep-sleep level to about 3 %/hour (measured on the author's tablet without the module).
#
# Status on the author's tablet: the cameras do NOT work (no I2C answer, also in Windows with the factory
# drivers: STATUS_DEVICE_POWER_FAILURE) - a hardware fault. On a tablet with working cameras this should work,
# but it was never seen working. Undo with:  sh ~/digma-citi1804-linux/camera/disable.sh
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
KVER=$(ls /lib/modules | grep -- '-lts$' | sort -V | tail -n1); V=${KVER%%-*}
U=/lib/modules/$KVER/updates
FW=/lib/firmware/shisp_2401a0_v21.bin
FW_URL=https://raw.githubusercontent.com/intel-aero/meta-intel-aero-base/master/recipes-kernel/linux/linux-yocto/shisp_2401a0_v21.bin
FW_SHA=e89359f4e4934c410c83d525e283f34c5fcce9cb5caa75ad8a32d66d3842d95c
[ "$(id -u)" != 0 ] || { echo "Run as the normal user, not with sudo." >&2; exit 1; }

if [ "$V" != 6.18.63 ]; then
	echo "The bundled camera sources are from kernel 6.18.63, the installed kernel is $KVER." >&2
	echo "Replace camera/src/{atomisp,ov2680.c,gc0310.c,ipu-bridge.c} with the files of the same kernel version" >&2
	echo "(drivers/staging/media/atomisp, drivers/media/i2c, drivers/media/pci/intel) and run again." >&2
	exit 1
fi

echo "== 1. ISP firmware (Intel, from the Intel Aero repository, checked by SHA-256)"
if [ ! -f "$FW" ] || [ "$(sha256sum "$FW" | cut -d' ' -f1)" != "$FW_SHA" ]; then
	T=$(mktemp); wget -q -O "$T" "$FW_URL"
	[ "$(sha256sum "$T" | cut -d' ' -f1)" = "$FW_SHA" ] || { echo "firmware checksum mismatch" >&2; rm -f "$T"; exit 1; }
	sudo install -m644 "$T" "$FW"; rm -f "$T"
fi
echo "firmware OK"

echo "== 2. Build the camera modules for $KVER (about 4 minutes)"
B=$(mktemp -d); trap 'rm -rf "$B"' EXIT
cp -r "$REPO/camera/src/." "$B/"
(cd "$B" && make KVER="$KVER" -j"$(nproc)" >"$B/build.log" 2>&1) || { tail -20 "$B/build.log"; exit 1; }

echo "== 3. Install (deep-sleep module removed)"
sudo rm -f "$U/intel_atomisp2_pm.ko"
for m in ipu-bridge.ko ov2680.ko gc0310.ko atomisp/atomisp.ko atomisp/pci/atomisp_gmin_platform.ko; do
	sudo install -D -m644 "$B/$m" "$U/$(basename "$m")"
done
sudo depmod "$KVER"
echo "Done. Reboot: sudo reboot"
echo "Check afterwards: ls /dev/video*   and   cam -l  (package libcamera-tools)"
