#!/bin/sh
# Read-only check of the new settings.
echo "## touch cmdline file"; ls -la /etc/kernel-cmdline.d; cat /etc/kernel-cmdline.d/*.conf
echo "## modules file"; ls -la /etc/mkinitfs/modules; cat -A /etc/mkinitfs/modules/*.modules
echo "## generated cmdline"; generate-kernel-cmdline 2>&1
echo "## home"; ls -la ~ | head -20
echo "## uptime"; uptime
