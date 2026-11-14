#!/bin/sh
# Read-only: how the initramfs loads modules; Bluetooth; sound server.
echo "## initramfs pkg files"
apk info -L postmarketos-initramfs postmarketos-mkinitfs 2>&1 | grep -v '^$' | head -50
echo "## grep module loading in init scripts"
grep -rnE "modprobe|initramfs.load|udevadm|load_modules|systemd-modules" /usr/share/initramfs/ /usr/share/mkinitfs/ /usr/lib/mkinitfs 2>/dev/null | head -40
echo "## files lists"
for f in /usr/share/mkinitfs/files/*.files /usr/share/mkinitfs/files-extra/*.files; do echo "--- $f"; cat "$f"; done
echo "## modprobe.d"
ls -la /etc/modprobe.d /usr/lib/modprobe.d /lib/modprobe.d 2>&1
echo "## i915 softdeps"
modinfo i915 | grep -iE "softdep|^depends"
modinfo pwm-lpss-platform | grep -E "depends|alias"
modinfo axp20x-i2c | grep -E "depends|alias" | head
echo "## hci_uart"
modinfo hci_uart | grep -iE "OBDA|RTL|depends|serdev" | head
ls /lib/modules/$(uname -r)/kernel/drivers/bluetooth/ 2>&1
cat /sys/bus/serial/devices/serial0-0/modalias 2>&1
ls -la /sys/bus/serial/devices/serial0-0/ 2>&1
echo "## pactl"
pactl info 2>&1 | head -14
pactl list short cards 2>&1
pactl list short sinks 2>&1
pactl list short sources 2>&1
echo "## ucm"
ls /usr/share/alsa/ucm2/Intel/ 2>&1 | head -40
ls /usr/share/alsa/ucm2/conf.d/ 2>&1 | grep -iE "byt|cht|sof"
alsaucm -c hw:1 list _verbs 2>&1 | head
echo "## kernel modules of interest"
find /lib/modules/$(uname -r) -iname "*atomisp*" -o -iname "*ov2680*" -o -iname "*gc0310*" -o -iname "*hci_uart*" -o -iname "*btrtl*" | head
echo "## busybox/kmod modprobe"
ls -la $(command -v modprobe)
