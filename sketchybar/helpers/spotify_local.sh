#!/bin/sh

# Local Spotify Connect source for the SketchyBar music widget.
#
# Replaces the Web API daemon (spotify_connect.sh, kept dormant) with the same
# local mechanism simple-bar uses: Spotify Desktop's AppleScript dictionary
# follows the ACTIVE Spotify Connect session, so a phone playback session is
# visible locally with full metadata AND live progress (verified: AppleScript
# position advances in real time while media-control's elapsedTime stays
# frozen at ~0 for remote sessions).
#
# Modes:
#   (no args)      daemon: poll Spotify AppleScript, emit spotify_update events
#   control CMD    transport command (play|pause|next|previous) against the
#                  ACTIVE Connect device (verified working remotely)
#
# Poll cadence: 5s playing, 15s paused/stopped, 30s when Spotify is closed.
# One osascript round-trip per poll (no per-frame spawning, no fast loops).
#
# Artwork: AppleScript artwork extraction (raw data of artwork) no longer
# compiles on macOS 26, so artwork is taken from the generic media-control
# Now Playing snapshot WHEN its title matches the AppleScript title (verified:
# media-control carries artworkData for remote Spotify sessions) and decoded
# to ART_FILE only on checksum change. No artwork when the Mac Spotify app is
# closed (documented limitation).
#
# NOTE: Spotify must stay open on the Mac for this source; closing it drops
# remote visibility by design (simple-bar behaves the same).

PATH="/opt/homebrew/bin:$PATH"
ART_FILE="/tmp/sketchybar_spotify_local_art_${USER}.jpg"
last_art_sum="__none__"
last_state=""

emit() {
	sketchybar --trigger spotify_update "INFO=$1"
}

# One AppleScript round-trip: state|title|artist|album|duration_ms|position
# NOTE: variable names are p-prefixed because short names like `st` collide
# with terminology in Spotify's dictionary and fail to compile (-2741).
# Bounded by a 4s watchdog: osascript can hang ~60s waiting for an AppleEvent
# reply when Spotify is mid-Connect-transition; `osascript -t` is unsupported
# on this macOS, so we run it in background and kill the straggler.
PROBE_TMP="/tmp/spotify_local_probe_${USER}.out"
probe() {
	(
		osascript <<'ASC' 2>/dev/null > "$PROBE_TMP"
tell application "Spotify"
	set pstate to player state as string
	set ptitle to ""
	set partist to ""
	set palbum to ""
	set pdur to "0"
	set ppos to "0"
	try
		set ptrack to current track
		set ptitle to name of ptrack as string
		set partist to artist of ptrack as string
		set palbum to album of ptrack as string
		set pdur to duration of ptrack as string
	end try
	try
		set ppos to player position as string
	end try
	return pstate & "|" & ptitle & "|" & partist & "|" & palbum & "|" & pdur & "|" & ppos
end tell
ASC
	) &
	_ppid=$!
	( sleep 4; kill -9 "$_ppid" 2>/dev/null ) >/dev/null 2>&1 &
	_wpid=$!
	wait "$_ppid" 2>/dev/null
	kill "$_wpid" 2>/dev/null
	wait "$_wpid" 2>/dev/null
	cat "$PROBE_TMP" 2>/dev/null
}

# Grab artwork for the given title from the generic Now Playing snapshot.
# Only touches ART_FILE when media-control's title matches Spotify's (avoids
# showing another app's artwork next to Spotify metadata).
sync_art() {
	[ -n "$1" ] || return 0
	_mc=$(media-control get 2>/dev/null)
	[ -n "$_mc" ] || return 0
	_title=$(printf '%s' "$_mc" | jq -r '.title // ""' 2>/dev/null)
	[ "$_title" = "$1" ] || return 0
	_b64=$(printf '%s' "$_mc" | jq -r '.artworkData // empty' 2>/dev/null)
	[ -n "$_b64" ] || return 0
	_sum=$(printf '%s' "$_b64" | cksum | awk '{print $1 "." $2}')
	if [ "$_sum" != "$last_art_sum" ]; then
		printf '%s' "$_b64" | base64 --decode > "$ART_FILE" 2>/dev/null || : > "$ART_FILE"
		last_art_sum=$_sum
	fi
}

daemon() {
	interval=6
	announced_closed=0
	probe_fails=0
	while :; do
		if ! pgrep -xq Spotify; then
			if [ "$announced_closed" -eq 0 ]; then
				emit '{"source":"spotify_local","available":false}'
				announced_closed=1
				last_state=""
			fi
			sleep 30
			continue
		fi
		announced_closed=0

		p=$(probe)
		if [ -z "$p" ]; then
			# AppleScript can transiently fail right after Connect transitions
			# (app busy): retry quickly, only report "stopped" after 3 misses
			probe_fails=$((probe_fails + 1))
			if [ "$probe_fails" -ge 3 ] && [ "$last_state" != "stopped" ]; then
				emit '{"source":"spotify_local","playing":false}'
				last_state="stopped"
			fi
			sleep 3
			continue
		fi
		probe_fails=0
		state=${p%%|*}
		p=${p#*|}
		title=${p%%|*}
		p=${p#*|}
		artist=${p%%|*}
		p=${p#*|}
		album=${p%%|*}
		p=${p#*|}
		duration_ms=${p%%|*}
		position=${p#*|}

		case "$state" in
			playing)
				_payload=$(jq -cn \
					--arg t "$title" --arg ar "$artist" --arg al "$album" \
					--arg e "$position" --arg d "$duration_ms" --arg f "$ART_FILE" \
					'{source:"spotify_local", playing:true,
					  title:$t, artist:$ar, album:$al,
					  elapsed:($e|tonumber? // 0),
					  duration:(($d|tonumber? // 0)/1000),
					  device_name:"Spotify Connect", artwork_path:$f}')
				[ -n "$_payload" ] && emit "$_payload"
				sync_art "$title"
				interval=5
				;;
			paused)
				if [ "$last_state" != "paused" ]; then
					emit '{"source":"spotify_local","playing":false}'
					interval=6
				else
					interval=6
				fi
				;;
			*)
				if [ "$last_state" != "stopped" ]; then
					emit '{"source":"spotify_local","playing":false}'
				fi
				interval=6
				;;
		esac
		last_state=$state
		sleep "$interval"
	done
}

# control CMD: transport against the active Connect device. Fire-and-forget
# with a 5s watchdog (media.lua ignores the result); non-zero exit only for
# usage errors / Spotify not running.
cmd_control() {
	pgrep -xq Spotify || exit 1
	local _verb
	case "$1" in
		play) _verb="play" ;;
		pause) _verb="pause" ;;
		next) _verb="next track" ;;
		previous) _verb="previous track" ;;
		*) echo "unknown command: $1"; exit 1 ;;
	esac
	osascript -e "tell application \"Spotify\" to $_verb" >/dev/null 2>&1 &
	_cpid=$!
	( sleep 5; kill -9 "$_cpid" 2>/dev/null ) >/dev/null 2>&1 &
	return 0
}

case "${1:-}" in
	control) cmd_control "$2" ;;
	"") daemon ;;
	syncart) sync_art "$2"; echo "art exists: $([ -s "$ART_FILE" ] && echo yes || echo no) (ART_FILE=$ART_FILE)" ;;
	*) echo "usage: spotify_local.sh [control play|pause|next|previous]"; exit 1 ;;
esac
