#!/bin/sh
# Run with sudo. Pins the built-in display (DSI-1) to 150 % scale for every session.
# phosh-session uses /etc/phosh/phoc.ini instead of /usr/share/phosh/phoc.ini when it exists,
# so start from a copy of the system file and add the DSI-1 section.
set -eu
mkdir -p /etc/phosh
if [ ! -f /etc/phosh/phoc.ini ]; then
	cp /usr/share/phosh/phoc.ini /etc/phosh/phoc.ini
fi
if ! grep -q '^\[output:DSI-1\]' /etc/phosh/phoc.ini; then
	printf '\n[output:DSI-1]\nscale = 1.5\n' >> /etc/phosh/phoc.ini
fi
cat /etc/phosh/phoc.ini
echo "Done. Reboot (or log out and back in) to apply."
