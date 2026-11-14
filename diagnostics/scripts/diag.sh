#!/bin/sh
# Read-only diagnostics for the tablet. Changes nothing.
echo "### os"; cat /etc/os-release; uname -a
echo "### initfs config"; ls -laR /etc/mkinitfs /usr/share/mkinitfs /etc/postmarketos-mkinitfs /usr/share/postmarketos-mkinitfs 2>&1
echo "### initfs module lists"; for f in /usr/share/mkinitfs/modules/* /etc/mkinitfs/modules/* /usr/share/postmarketos-mkinitfs/modules/* /etc/postmarketos-mkinitfs/modules/*; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done
echo "### deviceinfo"; for f in /usr/share/deviceinfo/* /etc/deviceinfo; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done
echo "### boot dir"; ls -la /boot /boot/loader/entries 2>&1
echo "### backlight"; for d in /sys/class/backlight/*; do echo "$d"; ls -la "$d"; cat "$d/type" "$d/brightness" "$d/max_brightness" "$d/actual_brightness" 2>&1; done
echo "### pwm"; ls -la /sys/class/pwm/ /sys/bus/platform/drivers/pwm-lpss /sys/bus/acpi/devices 2>&1 | grep -iE "pwm|80862288|80862289|total"
echo "### kconfig"; zcat /proc/config.gz 2>&1 | grep -E "PWM_LPSS|PWM_CRC|MFD_AXP20X|INTEL_SOC_PMIC|I2C_DESIGNWARE|DRM_I915=|TOUCHSCREEN_DMI|TOUCHSCREEN_SILEAD|ATOMISP|VIDEO_OV2680|VIDEO_GC0310|BT_HCIUART|SERIAL_DEV|MODULE_COMPRESS|ACPI_PMIC|PMIC_OPREGION|XPOWER|EXTCON_AXP|AXP288"
ls -la /boot/config* /proc/config.gz 2>&1
echo "### modinfo"; for m in pwm-lpss-platform pwm_lpss_platform axp20x-i2c i915 hci_uart intel_atomisp atomisp ov2680 atomisp_gc0310 gc0310; do modinfo -F filename "$m" 2>&1 | sed "s|^|$m: |"; done
echo "### lsmod"; lsmod
echo "### packages"; apk list -I 2>/dev/null | grep -iE "mkinitfs|boot-deploy|kmod|phosh|phoc|^linux-|sof|ucm|firmware|bluez|thermald|iio|device-|postmarketos-base|systemd-boot|libcamera|pipewire|wireplumber|upower"
echo "### failed units"; systemctl --failed --no-pager 2>&1
echo "### rfkill"; rfkill 2>&1; cat /sys/class/rfkill/*/name /sys/class/rfkill/*/type 2>&1
echo "### serial devices"; ls -la /sys/bus/serial/devices 2>&1; ls /sys/bus/acpi/devices | grep -iE "OBDA|RTK|BCM|8086228A"
for d in /sys/bus/acpi/devices/OBDA8723:00 /sys/bus/acpi/devices/8086228A:00 /sys/bus/acpi/devices/8086228A:01; do echo "$d status=$(cat $d/status 2>&1) path=$(cat $d/path 2>&1)"; ls "$d" 2>&1 | tr '\n' ' '; echo; done
echo "### power"; for f in /sys/class/power_supply/*/uevent; do echo "--- $f"; cat "$f"; done
echo "### thermal"; for z in /sys/class/thermal/thermal_zone*; do echo "$z $(cat $z/type) $(cat $z/temp)"; done; for c in /sys/class/thermal/cooling_device*; do echo "$c $(cat $c/type) $(cat $c/cur_state)/$(cat $c/max_state)"; done
echo "### iio"; for d in /sys/bus/iio/devices/*; do echo "$d $(cat $d/name 2>&1)"; ls "$d" | tr '\n' ' '; echo; cat "$d"/*mount_matrix 2>&1; done
echo "### audio"; aplay -l 2>&1; wpctl status 2>&1 | head -60
echo "### environment"; cat /etc/environment
echo "### sessions"; ps -eo user,args | grep -E "phoc|phosh|greetd|phrog|tinydm" | grep -v grep
echo "### memory"; free -m; cat /proc/swaps; zramctl 2>&1
echo "### disk"; df -h / /boot; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
echo "### sleep"; cat /sys/power/state /sys/power/mem_sleep 2>&1
echo "### video devices"; ls -la /dev/video* /dev/media* 2>&1
echo "### firmware dirs"; ls /lib/firmware | head -80; ls -la /lib/firmware/silead /lib/firmware/rtl_bt 2>&1 | head -30; ls /lib/firmware/intel 2>&1 | head -40
