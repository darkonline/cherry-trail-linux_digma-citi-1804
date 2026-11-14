#!/bin/sh
# Logs battery state every 10 minutes to ~/battery-log.txt while the tablet is awake.
# Suspend pauses it; the first line after wake-up shows how much the battery dropped during sleep.
# Started with: systemd-run --user --unit=battery-log ~/.local/bin/battery-log.sh
# Stop with:    systemctl --user stop battery-log
b=/sys/class/power_supply/axp288_fuel_gauge
c=/sys/class/power_supply/axp288_charger
while :; do
	echo "$(date '+%F %T') status=$(cat $b/status) cap=$(cat $b/capacity)% charge_uAh=$(cat $b/charge_now) V=$(cat $b/voltage_now) charger_online=$(cat $c/online)" >> ~/battery-log.txt
	sleep 600
done
