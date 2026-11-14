#!/bin/sh
# Run with sudo. Makes the mono-speaker fix permanent and returns the audio DSP to the default SOF driver.
# Digma CITI 1804 has one speaker on a differential amp between the codec's LOUT L and R.
# bytcr_rt5651 quirk 0x823412 = driver defaults for this board (MCLK_EN | JD1_1 | OVCD 2000uA | OVCD SF 0.75 | IN2_MAP)
#                               + BYT_RT5651_MONO_SPEAKER (bit 23) -> ALSA UCM uses codecs/rt5651/MonoSpeaker.conf
# Undo: sudo rm /etc/kernel-cmdline.d/91-citi1804-audio.conf && sudo mkinitfs && reboot
set -eu
echo 'snd_soc_sst_bytcr_rt5651.quirk=8533010' > /etc/kernel-cmdline.d/91-citi1804-audio.conf
mkinitfs
echo "== boot entry:"
grep -E '^(linux|options)' /boot/loader/entries/pmos.conf
echo "Done. Reboot to apply."
