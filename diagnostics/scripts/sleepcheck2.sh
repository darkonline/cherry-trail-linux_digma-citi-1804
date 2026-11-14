#!/bin/sh
# Read-only: suspend/resume log.
echo "## now"; date; uptime; cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail /sys/power/suspend_stats/last_failed_dev 2>&1
echo "## kernel from first suspend"; journalctl -k -b --no-pager -o short 2>&1 | awk '/PM: suspend entry/{f=1} f' | cut -c1-230 | tail -90
echo "## userspace around resume"; journalctl -b --no-pager -o short 2>&1 | grep -iE "PM: suspend (entry|exit)|logind.*(Power key|Lid|suspend|sleep|wake)|phosh.*(power|blank|key)|DSI-1: (Turning off|Modesetting)|systemd-sleep|Reached target.*[Ss]leep|Stopped target.*[Ss]leep|gpio-keys|button" | tail -40 | cut -c1-200
echo "## wake sources"; grep -E "enabled" /proc/acpi/wakeup 2>&1 | head -20
for d in /sys/devices/platform/ACPI0011:00/gpio-keys.*/power/wakeup /sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0C0C:00/power/wakeup; do echo "$d $(cat $d 2>&1)"; done
echo "## logind config"; grep -vE "^#|^$" /etc/systemd/logind.conf /etc/systemd/logind.conf.d/* /usr/lib/systemd/logind.conf.d/* 2>&1
echo "## state"; cat /sys/class/power_supply/axp288_fuel_gauge/status /sys/class/power_supply/axp288_fuel_gauge/capacity /sys/class/power_supply/axp288_fuel_gauge/current_now; grep "=1" /sys/class/extcon/extcon0/state
