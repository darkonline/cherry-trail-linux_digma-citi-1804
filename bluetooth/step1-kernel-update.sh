#!/bin/sh
# Step 1 (run with sudo): back up the working 6.18.60 kernel, add a backup boot entry,
# then update linux-lts and install the build tools.
set -eu
OLD=6.18.60-0-lts

echo "== 1. Backup of the current kernel, initramfs and modules"
[ -f /boot/vmlinuz-6.18.60.bak ]   || cp /boot/vmlinuz-lts /boot/vmlinuz-6.18.60.bak
[ -f /boot/initramfs-6.18.60.bak ] || cp /boot/initramfs   /boot/initramfs-6.18.60.bak
[ -d /root/modules-6.18.60.bak ]   || cp -a /lib/modules/$OLD /root/modules-6.18.60.bak

echo "== 2. Backup boot entry (selectable in the boot menu)"
sed -e 's/^title .*/title postmarketOS 6.18.60 (backup)/' \
    -e 's/^sort-key .*/sort-key zz-backup/' \
    -e 's|^linux .*|linux vmlinuz-6.18.60.bak|' \
    -e 's|^initrd[[:space:]]\{1,\}initramfs$|initrd initramfs-6.18.60.bak|' \
    /boot/loader/entries/pmos.conf > /boot/loader/entries/pmos-backup.conf
if [ ! -f /boot/loader/loader.conf ]; then
	printf 'default pmos.conf\ntimeout 3\n' > /boot/loader/loader.conf
fi

echo "== 3. Kernel update and build tools"
apk update
apk add -u linux-lts linux-lts-dev build-base

echo "== 4. Put the old modules back so the backup entry stays usable"
[ -d /lib/modules/$OLD ] || cp -a /root/modules-6.18.60.bak /lib/modules/$OLD

echo "== Done. Do NOT reboot yet; let Claude check /boot first."
ls /lib/modules
