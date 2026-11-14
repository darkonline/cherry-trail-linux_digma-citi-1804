#!/bin/sh
# Read-only: sample charger / battery / thermal state a few times.
i=0
while [ $i -lt 6 ]; do
  b=/sys/class/power_supply/axp288_fuel_gauge; c=/sys/class/power_supply/axp288_charger
  echo "$(date +%T) status=$(cat $b/status) cap=$(cat $b/capacity)% V=$(cat $b/voltage_now) I=$(cat $b/current_now) chg_now=$(cat $b/charge_now) | online=$(cat $c/online) present=$(cat $c/present) health=$(cat $c/health) in_lim=$(cat $c/input_current_limit) cc=$(cat $c/constant_charge_current) | TCHG=$(for d in /sys/class/thermal/cooling_device*; do [ "$(cat $d/type)" = TCHG ] && cat $d/cur_state; done) temps=$(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')"
  i=$((i+1)); sleep 5
done
echo "## extcon"; for e in /sys/class/extcon/*; do echo "$e $(cat $e/name 2>/dev/null)"; cat $e/state 2>/dev/null; done
echo "## usb role"; cat /sys/class/usb_role/*/role 2>&1
echo "## adc"; for f in /sys/bus/iio/devices/iio:device1/in_*_raw; do echo "$f $(cat $f)"; done
echo "## thermal zone types"; for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type) $(cat $z/temp) policy=$(cat $z/policy 2>/dev/null) trips=$(cat $z/trip_point_*_temp 2>/dev/null | tr '\n' ' ')"; done
echo "## upower"; upower -i /org/freedesktop/UPower/devices/battery_axp288_fuel_gauge 2>&1 | grep -E "state|percentage|energy-rate|time|voltage"
echo "## thermald/tuned"; ps -eo args | grep -E "thermald|tuned|power-profiles" | grep -v grep
echo "## journal power"; journalctl -k -b --no-pager 2>&1 | grep -iE "axp288|extcon|charger|fuel|vbus|usb role|thermal|TCHG|dptf|int340" | head -30
