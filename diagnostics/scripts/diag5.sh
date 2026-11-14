#!/bin/sh
# Read-only: kernel cmdline config fragments.
for d in /usr/lib/kernel-cmdline.d /etc/kernel-cmdline.d /usr/share/kernel-cmdline.d; do echo "## $d"; ls -la "$d" 2>&1; for f in "$d"/*; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done; done
echo "## generator"; command -v generate-kernel-cmdline; file "$(command -v generate-kernel-cmdline)" 2>&1; head -60 "$(command -v generate-kernel-cmdline)" 2>&1
echo "## generated now"; generate-kernel-cmdline 2>&1
