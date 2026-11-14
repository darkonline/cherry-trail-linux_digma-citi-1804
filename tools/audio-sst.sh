#!/bin/sh
# Run with sudo. Switches the onboard audio DSP driver from SOF to the older Intel SST driver
# (kernel parameter snd_intel_dspcfg.dsp_driver=2) and regenerates the boot entry.
# Undo: sudo rm /etc/kernel-cmdline.d/91-citi1804-audio.conf && sudo mkinitfs && reboot
set -eu
echo 'snd_intel_dspcfg.dsp_driver=2' > /etc/kernel-cmdline.d/91-citi1804-audio.conf
mkinitfs
echo "== boot entry options:"
grep '^options' /boot/loader/entries/pmos.conf
echo "== kernel file in entry:"
grep '^linux' /boot/loader/entries/pmos.conf
echo "Done. Reboot to apply."
