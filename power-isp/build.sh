#!/bin/sh
# Builds intel_atomisp2_pm.ko for the running kernel (run as normal user, no sudo).
# The module powers off the unused camera ISP (PCI 8086:22b8) so the SoC can enter S0i3 during suspend.
# Without it, suspend draws ~200 mA (~3.2 %/h); with it the SoC reaches S0i3.
# pm.c is the unmodified drivers/platform/x86/intel/atomisp2/pm.c from kernel 6.18.63 (GPL-2.0).
# Re-run after every kernel update. Remove the module if you ever use the atomisp camera driver.
set -eu
cd "$(dirname "$0")"
make clean >/dev/null 2>&1 || true
make
echo "Install:  sudo install -D -m644 intel_atomisp2_pm.ko /lib/modules/\$(uname -r)/updates/intel_atomisp2_pm.ko && sudo depmod \$(uname -r) && sudo reboot"
