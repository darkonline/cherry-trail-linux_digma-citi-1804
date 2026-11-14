#!/bin/sh
# Read-only check after reboot.
echo "## uptime"; uptime; cat /proc/cmdline
echo "## backlight"; for d in /sys/class/backlight/*; do echo "$d type=$(cat $d/type) cur=$(cat $d/brightness) max=$(cat $d/max_brightness) actual=$(cat $d/actual_brightness)"; done
echo "## pwm"; ls /sys/class/pwm/ 2>&1; cat /sys/kernel/debug/pwm 2>&1 | head -5
echo "## module init order hints"; ls -la --time-style=full-iso /sys/module/i915/initstate /sys/module/pwm_lpss_platform/initstate /sys/module/axp20x_i2c/initstate 2>&1
for m in i915 pwm_lpss_platform axp20x_i2c; do echo "$m: $(stat -c %y /sys/module/$m 2>&1)"; done
echo "## input"; grep -E "^N:" /proc/bus/input/devices
echo "## power"; grep -E "STATUS|ONLINE|CAPACITY=|CURRENT_NOW|INPUT_CURRENT" /sys/class/power_supply/*/uevent
echo "## journal kernel (if permitted)"; journalctl -k -b --no-pager 2>&1 | grep -iE "pwm|PMIC|backlight|mipi|i915.*(ERROR|WARN)|axp20x|silead" | head -30
