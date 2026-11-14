#!/bin/sh
# Read-only: boot-deploy cmdline handling, mkinitfs config search paths.
echo "## boot-deploy files"; apk info -L boot-deploy 2>&1 | grep -v '^$'
echo "## cmdline handling"; grep -rnE "cmdline" /usr/sbin/boot-deploy /usr/share/boot-deploy/ 2>/dev/null | head -40
echo "## systemd-boot entry generation"; grep -nE "pmos.conf|loader/entries|options |sort-key" -r /usr/sbin/boot-deploy /usr/share/boot-deploy/ 2>/dev/null | head -20
echo "## mkinitfs strings"; strings /usr/sbin/mkinitfs | grep -E "^/etc/mkinitfs|^/usr/share/mkinitfs|initramfs.load|\.modules|\.files" | sort -u | head -30
echo "## deviceinfo sourcing"; cat /usr/share/misc/source_deviceinfo
echo "## kernel cmdline pieces in deviceinfo-like files"; grep -rn "cmdline" /usr/share/deviceinfo /etc/deviceinfo /etc/kernel 2>/dev/null | head
ls -la /etc/kernel /usr/lib/kernel 2>&1 | head -20
