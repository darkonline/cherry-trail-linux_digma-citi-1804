#!/bin/sh
# Read-only logger: battery / charger / thermal every 10 s, 90 samples (15 min).
b=/sys/class/power_supply/axp288_fuel_gauge; c=/sys/class/power_supply/axp288_charger
echo "time status cap V_uV I_uA charge_uAh online health in_lim cc TCHG extcon role bl | temps(INT3400 STR0 acpitz PNIT dts0 dts1) | cpufreq load"
i=0
while [ $i -lt 90 ]; do
  tchg=""; for d in /sys/class/thermal/cooling_device*; do [ "$(cat $d/type)" = TCHG ] && tchg=$(cat $d/cur_state); done
  ext=$(grep -l "=1" /dev/null 2>/dev/null; grep "=1" /sys/class/extcon/extcon0/state | tr '\n' ',')
  echo "$(date +%T) $(cat $b/status) $(cat $b/capacity) $(cat $b/voltage_now) $(cat $b/current_now) $(cat $b/charge_now) $(cat $c/online) $(cat $c/health) $(cat $c/input_current_limit) $(cat $c/constant_charge_current) $tchg $ext $(cat /sys/class/usb_role/*/role) $(cat /sys/class/backlight/intel_backlight/brightness) | $(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')| $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) $(cut -d' ' -f1 /proc/loadavg)"
  i=$((i+1)); sleep 10
done
echo DONE
