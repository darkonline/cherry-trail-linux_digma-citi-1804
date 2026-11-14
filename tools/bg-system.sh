#!/bin/sh
# Run with sudo. Removes the phone apps (no modem / SIM in this tablet) and disables ModemManager.
# calls  -> also removes callaudiod;  chatty -> also removes mmsd-tng (if nothing else needs them).
# ModemManager itself stays installed (postmarketos-base-ui-gnome depends on it) but is disabled.
# Undo: apk add calls chatty && systemctl enable --now ModemManager
set -eu
apk del calls chatty
systemctl disable --now ModemManager.service
echo "done"
