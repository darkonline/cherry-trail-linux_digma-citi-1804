#!/bin/sh
# Read-only: what happened around suspend/resume, and touchscreen state now.
echo "## now"; date; uptime
echo "## suspend/resume timeline"; journalctl -b --no-pager -o short 2>&1 | grep -iE "PM: |suspend|resume|s2idle|Freezing|Restarting tasks|lid|sleep-inhibitor.*inhibiting|logind.*(sleep|suspend|lid|idle)|phosh.*(idle|blank|suspend)" | tail -40
echo "## kernel messages since first suspend entry"; journalctl -k -b --no-pager -o short 2>&1 | awk '/PM: suspend entry/{f=1} f' | cut -c1-240 | tail -120
echo "## touch device now"; grep -A8 silead_ts /proc/bus/input/devices
ls -la /sys/bus/i2c/devices/ | grep -i MSSL; cat /sys/bus/i2c/devices/i2c-MSSL1680:00/power/runtime_status /sys/bus/i2c/devices/i2c-MSSL1680:00/power/control 2>&1
ls /sys/bus/i2c/drivers/silead_ts/ 2>&1
echo "## silead driver params"; modinfo silead | grep -iE "parm|version|alias" | head
echo "## backlight / display"; cat /sys/class/backlight/intel_backlight/brightness /sys/class/backlight/intel_backlight/actual_brightness
echo "## wifi"; ip -4 addr show wlan0 | grep inet
echo "## s0ix residency (if readable)"; cat /sys/kernel/debug/pmc_atom/sleep_state 2>&1 | head -12; cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail 2>&1
