#!/bin/sh
# Run with sudo. Fixes the boot entries after the kernel update:
# boot-deploy picks the FIRST /boot/vmlinuz* file, so the backup name
# vmlinuz-6.18.60.bak was wrongly used for the main entry.
# Moves the backup kernel into /boot/backup/ and points the entries correctly.
set -eu
mkdir -p /boot/backup
[ -f /boot/vmlinuz-6.18.60.bak ]   && mv /boot/vmlinuz-6.18.60.bak   /boot/backup/vmlinuz-6.18.60
[ -f /boot/initramfs-6.18.60.bak ] && mv /boot/initramfs-6.18.60.bak /boot/backup/initramfs-6.18.60

sed -i -e 's|^linux .*|linux /backup/vmlinuz-6.18.60|' \
       -e 's|^initrd[[:space:]]\{1,\}initramfs-6.18.60.bak$|initrd /backup/initramfs-6.18.60|' \
       /boot/loader/entries/pmos-backup.conf
sed -i 's|^linux .*|linux vmlinuz-lts|' /boot/loader/entries/pmos.conf

{
	ls -la /boot /boot/backup
	for f in /boot/loader/loader.conf /boot/loader/entries/*.conf; do echo "--- $f"; cat "$f"; done
} > /home/user/bootcheck2.txt 2>&1
chown user /home/user/bootcheck2.txt
echo "Done. Do not reboot yet; check ~/bootcheck2.txt first."
