#!/bin/sh
# Read-only: initramfs init order and mkinitfs behaviour.
echo "## init.sh"; cat -n /usr/share/initramfs/init.sh | head -120
echo "## load_modules + mdev setup"; sed -n '295,320p' /usr/share/initramfs/init_functions.sh
grep -nE "mdev|setup_mdev|udev" /usr/share/initramfs/init_functions.sh | head -20
echo "## mdev.conf"; cat /usr/share/initramfs/mdev.conf
echo "## mkinitfs help"; mkinitfs -h 2>&1 | head -20
echo "## busybox modprobe softdep support?"; busybox modprobe 2>&1 | head -5; strings /bin/busybox 2>/dev/null | grep -ciE "softdep"
echo "## module deps"; modprobe --show-depends pwm-lpss-platform 2>&1; modprobe --show-depends axp20x-i2c 2>&1; modprobe --show-depends i2c-designware-platform 2>&1 | tail -3
ls /lib/modules/$(uname -r)/kernel/drivers/i2c/busses/ | grep -i designware
echo "## bt serdev supplier"; cat /sys/bus/serial/devices/serial0-0/waiting_for_supplier; cat /sys/bus/serial/devices/serial0-0/uevent
modinfo hci_uart | grep -E "^alias" | head -20
