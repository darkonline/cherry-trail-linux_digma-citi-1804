#!/bin/sh
# Digma CITI 1804: quieter and smoother boot. Run as root:  sudo sh tools/boot-polish.sh
# Undo everything:                                          sudo sh tools/boot-polish.sh --undo
# Only own files are added (no package file is edited), so OS updates do not undo or break it.
#  1. kernel parameters: no kernel/udev text and no blinking cursor on the screen;
#     console=tty9 sends all console text (also the initramfs "mount: configfs" message and
#     emergency messages!) to the invisible VT 9. If boot breaks, look via SSH or remove it.
#  2. no boot menu (systemd-boot timeout 0; hold Space at power-on to get the menu)
#  3. boot logo theme "citi1804": a copy of pmos-spin that does not print "Loading"/"Starting"
#     (errors and warnings are still shown)
#  4. login screen (phrog) in the system language; it runs on the same VT as the boot logo
#  5. the boot logo stays on the screen until the login screen takes the display (like GDM:
#     plymouth deactivate, then quit --retain-splash once the login screen has drawn)
# Then reboot.
set -eu
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

CMDLINE=/etc/kernel-cmdline.d/93-citi1804-quiet.conf
THEME_SRC=/usr/share/plymouth/themes/pmos-spin
THEME=/usr/share/plymouth/themes/citi1804
PLYCONF=/etc/plymouth/plymouthd.conf
QUIT_DROPIN=/etc/systemd/system/plymouth-quit.service.d/citi1804-retain-splash.conf
WAIT_DROPIN=/etc/systemd/system/plymouth-quit-wait.service.d/citi1804-no-wait.conf
FINISH_UNIT=/etc/systemd/system/citi1804-plymouth-finish.service
HANDOFF_PATH=/etc/systemd/system/citi1804-plymouth-handoff.path
HANDOFF_SERVICE=/etc/systemd/system/citi1804-plymouth-handoff.service
TMPFILES=/etc/tmpfiles.d/citi1804.conf
GREETD_CONF=/etc/greetd/citi1804-phrog.toml
# same file name as the drop-in of the phrog package, so this one replaces it
GREETD_DROPIN=/etc/systemd/system/greetd.service.d/override.conf

if [ "${1:-}" = "--undo" ]; then
	systemctl disable citi1804-plymouth-finish.service citi1804-plymouth-handoff.path 2>/dev/null || true
	rm -f "$CMDLINE" "$QUIT_DROPIN" "$WAIT_DROPIN" "$FINISH_UNIT" "$HANDOFF_PATH" "$HANDOFF_SERVICE" "$TMPFILES" "$GREETD_DROPIN" "$GREETD_CONF"
	rmdir /etc/systemd/system/plymouth-quit.service.d /etc/systemd/system/plymouth-quit-wait.service.d /etc/systemd/system/greetd.service.d /etc/greetd 2>/dev/null || true
	rm -rf "$THEME"
	if grep -q 'citi1804' "$PLYCONF" 2>/dev/null; then
		printf '# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n' > "$PLYCONF"
	fi
	bootctl set-timeout '' || true
	systemctl daemon-reload
	mkinitfs
	echo "undone; reboot now"
	exit 0
fi

echo "== 1. kernel parameters"
install -D -m644 /dev/null "$CMDLINE"
echo 'loglevel=3 systemd.show_status=false rd.udev.log_level=3 udev.log_level=3 vt.global_cursor_default=0 console=tty9' > "$CMDLINE"

# (an earlier version added configfs here; it cannot help: the initramfs mounts configfs
#  before it loads any module, and this kernel has no USB gadget support anyway)
MODS=/etc/mkinitfs/modules/00-citi1804.modules
[ -f "$MODS" ] && sed -i '/^configfs$/d' "$MODS"

echo "== 2. no boot menu"
bootctl set-timeout 0

echo "== 3. boot logo without Loading/Starting"
[ -f "$THEME_SRC/pmos-spin.script" ] || { echo "theme $THEME_SRC not found" >&2; exit 1; }
rm -rf "$THEME"
mkdir -p "$THEME"
cp "$THEME_SRC"/*.png "$THEME/"
# show a message only when the splash is in the error or warning state
awk '
	{ print }
	/^fun display_message_callback\(text\)/ { want = 1; next }
	want && /^\{/ { print "    if (global.status != \"error\" && global.status != \"warning\")"; print "        return;"; want = 0 }
' "$THEME_SRC/pmos-spin.script" > "$THEME/citi1804.script"
grep -q 'global.status != "error"' "$THEME/citi1804.script" || { echo "could not patch the theme script" >&2; exit 1; }
cat > "$THEME/citi1804.plymouth" <<EOF
[Plymouth Theme]
Name=Digma CITI 1804 (postmarketOS spin, no status text)
Description=Copy of pmos-spin without the Loading/Starting text
ModuleName=script

[script]
ImageDir=$THEME
ScriptFile=$THEME/citi1804.script
EOF
printf '# citi1804: set by tools/boot-polish.sh (undo: --undo)\n[Daemon]\nTheme=citi1804\n' > "$PLYCONF"

echo "== 4. login: straight into Phosh, which starts locked (like a phone); phrog only after logout"
AUTOLOGIN_USER=${SUDO_USER:-}
[ -n "$AUTOLOGIN_USER" ] && [ "$AUTOLOGIN_USER" != root ] || { echo "run with sudo from your normal user" >&2; exit 1; }
mkdir -p /etc/greetd
cat > "$GREETD_CONF" <<EOF
# citi1804: like /etc/phrog/greetd-config.toml, but
#  - [initial_session]: at boot the Phosh session of $AUTOLOGIN_USER starts directly. Phosh locks
#    itself at start unless GDMSESSION=phosh (set by phrog), so the first screen is the Phosh
#    lock screen and after unlocking the desktop is already there (no second start).
#  - [default_session]: phrog, only after logging out
#  - on VT 1, where the boot logo is shown (no switch to a black text console)
#  - with the system language from /etc/locale.conf (greetd starts sessions without LANG)
#  - with the patched phoc wrapper first in PATH, if installed (phoc-fix); otherwise /usr/bin/phoc
[terminal]
vt = 1

[initial_session]
command = "/bin/sh -c 'unset GDMSESSION; set -a; . /etc/locale.conf; set +a; export XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=phosh XDG_CURRENT_DESKTOP=Phosh:GNOME; PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin; exec phosh-session'"
user = "$AUTOLOGIN_USER"

[default_session]
command = "/bin/sh -c 'set -a; . /etc/locale.conf; set +a; PATH=/usr/local/lib/citi1804/phoc:\$PATH; exec /usr/libexec/phrog-greetd-session'"
user = "greetd"
EOF
mkdir -p "$(dirname "$GREETD_DROPIN")"
cat > "$GREETD_DROPIN" <<EOF
# citi1804: replaces the phrog package drop-in (same file name), see $GREETD_CONF
[Service]
ExecStart=
ExecStart=greetd -c $GREETD_CONF
EOF

echo "== 5. keep the logo spinning until phoc draws (hand-over like GDM)"
# The logo keeps spinning while the session starts. Right before phoc needs the display, the
# phoc wrapper (phoc-fix) asks for it by creating /run/citi1804/plymouth-deactivate; the path
# unit below then "deactivates" plymouth (it stops drawing, the last frame stays on the screen)
# and answers with /run/citi1804/plymouth-deactivated. After phoc's first frame plymouth quits
# for real (citi1804-plymouth-finish). Without the phoc wrapper plymouth deactivates at the
# usual time (plymouth-quit), otherwise phoc could not get the display.
# greetd must not wait for plymouth to exit any more (plymouth-quit-wait has no timeout).
mkdir -p "$(dirname "$QUIT_DROPIN")" "$(dirname "$WAIT_DROPIN")"
mkdir -p "$(dirname "$TMPFILES")"
echo 'd /run/citi1804 1777 root root -' > "$TMPFILES"
systemd-tmpfiles --create "$TMPFILES"
cat > "$HANDOFF_PATH" <<'EOF'
[Unit]
Description=Hand the display from the boot splash to phoc on request (citi1804)

[Path]
PathExists=/run/citi1804/plymouth-deactivate

[Install]
WantedBy=multi-user.target
EOF
cat > "$HANDOFF_SERVICE" <<'EOF'
[Unit]
Description=Deactivate the boot splash for phoc (citi1804)

[Service]
Type=oneshot
ExecStart=-/usr/bin/plymouth deactivate
ExecStart=/bin/touch /run/citi1804/plymouth-deactivated
ExecStart=/bin/rm -f /run/citi1804/plymouth-deactivate
EOF
systemctl enable citi1804-plymouth-handoff.path
# written last, after everything it relies on is in place: without the phoc wrapper or the
# hand-over unit, plymouth deactivates at the usual time, otherwise phoc cannot get the display
cat > "$QUIT_DROPIN" <<'EOF'
[Service]
ExecStart=
ExecStart=-/bin/sh -c '[ -x /usr/local/lib/citi1804/phoc/phoc ] && [ -e /etc/systemd/system/citi1804-plymouth-handoff.path ] || /usr/bin/plymouth deactivate'
EOF
cat > "$WAIT_DROPIN" <<'EOF'
[Service]
ExecStart=
ExecStart=/bin/true
EOF
cat > "$FINISH_UNIT" <<'EOF'
[Unit]
Description=Quit the boot splash once the login screen has the display (citi1804)
After=greetd.service plymouth-quit.service

[Service]
Type=oneshot
# Quitting frees plymouth's last frame, so the screen goes black unless phoc already shows its
# own: wait (max ~40 s) until the login screen's phoc reports "Enabling shell mode" (its first
# frame, the startup shield, is up by then), give it 1 s, then quit.
ExecStart=/bin/sh -c 'i=0; until journalctl -b -q -g "Enabling shell mode" -n 1 | grep -q . || [ $$i -ge 130 ]; do sleep 0.3; i=$$((i+1)); done; sleep 1; /usr/bin/plymouth quit --retain-splash || true'

[Install]
WantedBy=graphical.target
EOF
systemctl enable citi1804-plymouth-finish.service

systemctl daemon-reload
echo "== mkinitfs (theme and kernel parameters)"
mkinitfs
echo "done; reboot now"
