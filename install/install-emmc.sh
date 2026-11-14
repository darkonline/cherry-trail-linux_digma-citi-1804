#!/bin/sh
# Copies the running postmarketOS system from the USB flash drive to the tablet's internal eMMC
# and makes it bootable. Run with sudo, while booted from the USB flash drive.
#
# !!! ERASES THE WHOLE eMMC: Windows and everything on it is deleted permanently. !!!
#
# The eMMC is found automatically: the only built-in MMC device (not an SD card, not USB)
# that does not hold the running system. If that is ambiguous, the script stops and lists
# the candidates; then pass one explicitly:  sudo DISK=/dev/mmcblkN sh install-emmc.sh
# Dry run (checks and shows the target, changes nothing):  sudo sh install-emmc.sh --check
# The USB flash drive is not modified and stays usable as a rescue system.
set -eu

MNT=/mnt/emmc
MIN_GIB=8
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

die() { echo "ERROR: $*" >&2; exit 1; }

# Block device (e.g. mmcblk1) that holds a mounted path.
disk_of() {
	src=$(findmnt -no SOURCE "$1" 2>/dev/null) || return 0
	src=$(readlink -f "$src")
	pk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1)
	[ -n "$pk" ] && echo "$pk" || basename "$src"
}

# ---------- tools ----------
[ "$(id -u)" = 0 ] || die "run with sudo"
for t in rsync efibootmgr parted wipefs mkfs.vfat mkfs.ext4 blkid lsblk findmnt; do
	command -v "$t" >/dev/null || die "$t missing: sudo apk add rsync efibootmgr parted dosfstools e2fsprogs util-linux"
done

# ---------- find the eMMC ----------
ROOT_DISK=$(disk_of /); BOOT_DISK=$(disk_of /boot)
[ -n "$ROOT_DISK" ] || die "cannot determine the disk of the running system"

if [ -n "${DISK:-}" ]; then
	dev=$(readlink -f "$DISK")
	[ -b "$dev" ] || die "$DISK is not a block device"
	name=$(basename "$dev")
else
	cands=""
	for d in /sys/block/mmcblk*; do
		[ -e "$d" ] || continue
		n=$(basename "$d")
		case "$n" in *boot*|*rpmb*) continue ;; esac   # eMMC hardware boot areas, never touched
		[ "$(cat "$d/device/type" 2>/dev/null)" = MMC ] || continue   # SD cards report "SD"
		[ "$n" = "$ROOT_DISK" ] || [ "$n" = "$BOOT_DISK" ] && continue
		cands="$cands $n"
	done
	set -- $cands
	[ $# -eq 0 ] && die "no internal eMMC found (are you booted from the eMMC itself?)"
	if [ $# -gt 1 ]; then
		echo "Several eMMC devices found:" >&2
		for n in "$@"; do lsblk -dno NAME,SIZE,MODEL "/dev/$n" >&2; done
		die "choose one: sudo DISK=/dev/mmcblkN sh $0"
	fi
	name=$1; dev=/dev/$name
fi

# ---------- safety checks ----------
case "$name" in mmcblk[0-9]*) ;; *) die "$dev is not an MMC device" ;; esac
case "$name" in *p[0-9]*|*boot*|*rpmb*) die "$dev is a partition or a hardware boot area, give the whole disk" ;; esac
[ "$(cat /sys/block/$name/device/type 2>/dev/null)" = MMC ] || die "$dev is not an eMMC (SD card?)"
[ "$name" != "$ROOT_DISK" ] && [ "$name" != "$BOOT_DISK" ] || die "$dev holds the running system"
[ "$(cat /sys/block/$name/removable)" = 0 ] || die "$dev is removable"
sectors=$(cat /sys/block/$name/size)
gib=$((sectors / 2097152))
[ "$gib" -ge "$MIN_GIB" ] || die "$dev is only $gib GiB"
if grep -q "^$dev" /proc/mounts; then die "a partition of $dev is mounted; unmount it first"; fi
byid=$(ls -l /dev/disk/by-id/ 2>/dev/null | awk -v n="$name" '$NF ~ "/"n"$" {print $(NF-2); exit}')

echo "Running system is on: /dev/$ROOT_DISK"
echo "Target eMMC:          $dev  ($(cat /sys/block/$name/device/name 2>/dev/null), $gib GiB${byid:+, $byid})"
echo "Current partitions on the target:"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$dev"
echo
if [ "$CHECK_ONLY" = 1 ]; then echo "Check only: nothing was changed."; exit 0; fi

echo "ALL DATA ON $dev (Windows and all files) WILL BE DESTROYED. This cannot be undone."
printf 'Type YES to continue: '
read -r answer
[ "$answer" = YES ] || die "aborted by user"

# ---------- partition and format ----------
for p in /dev/${name}p*; do [ -b "$p" ] && wipefs -a "$p" >/dev/null 2>&1 || true; done
wipefs -a "$dev"
parted -s "$dev" mklabel gpt \
	mkpart pmOS_boot fat32 1MiB 513MiB set 1 esp on \
	mkpart pmOS_root ext4 513MiB 100%
udevadm settle 2>/dev/null || true; sleep 2
mkfs.vfat -F 32 -n PMOS_BOOT "${dev}p1"
mkfs.ext4 -F -q -L pmOS_root "${dev}p2"
BOOT_UUID=$(blkid -s UUID -o value "${dev}p1")
ROOT_UUID=$(blkid -s UUID -o value "${dev}p2")
echo "boot UUID=$BOOT_UUID  root UUID=$ROOT_UUID"

# ---------- copy root filesystem ----------
mkdir -p "$MNT"
mount "${dev}p2" "$MNT"
rsync -aHAXx --numeric-ids --info=progress2 \
	--exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/run/*' \
	--exclude='/tmp/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/boot/*' \
	--exclude='/lost+found' --exclude='/var/cache/apk/*' \
	/ "$MNT/"

# ---------- copy boot files (no backups / test files) ----------
mkdir -p "$MNT/boot"
mount "${dev}p1" "$MNT/boot"
rsync -rt --info=progress2 \
	--exclude='backup/' --exclude='*.bak' --exclude='*.txt' --exclude='touch.bin' \
	--exclude='System Volume Information/' --exclude='loader/entries/pmos-backup.conf' \
	--exclude='loader/random-seed' \
	/boot/ "$MNT/boot/"

# ---------- point the new system at its own partitions ----------
cat > "$MNT/etc/fstab" <<EOF
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=$ROOT_UUID / ext4 defaults 0 0
UUID=$BOOT_UUID /boot vfat nodev,nosuid,noexec,umask=0077,nosymfollow,codepage=437,iocharset=ascii 0 0
EOF
E="$MNT/boot/loader/entries/pmos.conf"
[ -f "$E" ] || die "boot entry $E not found after copy"
sed -i -e "s/pmos_boot_uuid=[^ ]*/pmos_boot_uuid=$BOOT_UUID/" \
       -e "s/pmos_root_uuid=[^ ]*/pmos_root_uuid=$ROOT_UUID/" "$E"
printf 'default pmos.conf\ntimeout 2\n' > "$MNT/boot/loader/loader.conf"

# own copy of the boot loader, used by a firmware boot entry
mkdir -p "$MNT/boot/EFI/pmos"
cp "$MNT/boot/EFI/BOOT/BOOTIA32.EFI" "$MNT/boot/EFI/pmos/systemd-bootia32.efi"

echo "== new fstab:"; cat "$MNT/etc/fstab"
echo "== new boot entry:"; cat "$E"
echo "== boot partition:"; ls -la "$MNT/boot" "$MNT/boot/EFI"; df -h "$MNT" "$MNT/boot"

sync
umount "$MNT/boot" "$MNT"

# ---------- firmware boot entry (first in boot order) ----------
efibootmgr -c -d "$dev" -p 1 -L "postmarketOS (eMMC)" -l '\EFI\pmos\systemd-bootia32.efi' || \
	echo "WARNING: could not create UEFI boot entry; the firmware fallback \\EFI\\BOOT\\BOOTIA32.EFI will be used"
# remove the now dangling Windows firmware boot entries
for n in $(efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} Windows Boot Manager.*/\1/p'); do
	efibootmgr -q -b "$n" -B && echo "removed UEFI entry Boot$n (Windows Boot Manager)"
done
efibootmgr || true

echo
echo "DONE. Power off, REMOVE the USB flash drive, then power on."
