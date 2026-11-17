#!/bin/sh
# Digma CITI 1804: switch the onboard sound card between speaker and 3.5 mm jack automatically.
# With the rt5651 "Mono Speaker" UCM profile, Speaker and Headphones are conflicting devices, so
# PulseAudio puts them into different card profiles and does not switch between them on its own.
# This script watches PulseAudio card events and selects the matching profile.
# Runs as the normal user (systemd --user service jack-profile-switch.service).

# pactl output is parsed in English regardless of the session language
export LC_ALL=C LANG=C

CARD=alsa_card.platform-bytcr_rt5651
P_SPK="HiFi (Mic, Speaker)"
P_HP="HiFi (Headphones, Mic)"
P_HS="HiFi (Headphones, Headset)"

port_state() {   # $1 = port name; prints yes / no / unknown
	pactl list cards 2>/dev/null | awk -v card="$CARD" -v port="$1" '
		/^\tName: / { incard = ($2 == card) }
		incard && $0 ~ "^\t\t\\[(Out|In)\\] " port ":" {
			if ($0 ~ /not available/) print "no";
			else if ($0 ~ /availability unknown/) print "unknown";
			else if ($0 ~ /available/) print "yes";
			exit }'
}

active_profile() {
	pactl list cards 2>/dev/null | awk -v card="$CARD" '
		/^\tName: / { incard = ($2 == card) }
		incard && /^\tActive Profile: / { sub(/^\tActive Profile: /, ""); print; exit }'
}

apply() {
	hp=$(port_state Headphones)
	hs=$(port_state Headset)
	if [ "$hp" = yes ]; then
		if [ "$hs" = yes ]; then want=$P_HS; else want=$P_HP; fi
	else
		want=$P_SPK
	fi
	cur=$(active_profile)
	[ -z "$cur" ] && return
	if [ "$cur" != "$want" ]; then
		echo "jack: headphones=$hp headset=$hs -> profile '$want' (was '$cur')"
		pactl set-card-profile "$CARD" "$want"
		sink=$(pactl list short sinks | awk '$2 ~ /bytcr_rt5651/ { print $2; exit }')
		[ -n "$sink" ] && pactl set-default-sink "$sink"
	fi
}

# wait for PulseAudio
i=0
while ! pactl info >/dev/null 2>&1; do
	i=$((i + 1)); [ $i -gt 60 ] && { echo "PulseAudio not reachable"; exit 1; }
	sleep 2
done

apply
pactl subscribe | while read -r line; do
	case "$line" in
		*"on card"*) apply ;;
	esac
done
