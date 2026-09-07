#!/bin/sh

# Spotify Connect fallback source for the SketchyBar music widget.
#
# Modes:
#   (no args)   daemon: poll GET /v1/me/player and emit spotify_update events
#   control CMD one-shot transport command (next|previous|play|pause) against
#               the ACTIVE Connect device (no playback transfer)
#
# Security model:
#   - client_id / client_secret / refresh_token live ONLY in the macOS Keychain
#     (service "sketchybar-spotify")
#   - the short-lived access token is held in memory and cached in a 0600 file
#     in /tmp; it is never logged, echoed or passed on a command line
#   - secrets reach curl via a 0600 netrc file deleted immediately after use
#
# Poll cadence: 5s while Connect playback is active, 20s while idle, with
# exponential backoff (30s -> 300s cap) on errors and Retry-After on 429.
# Spotify API being down never affects local Now Playing: this daemon only
# emits spotify_update events.

PATH="/opt/homebrew/bin:$PATH"
SERVICE="sketchybar-spotify"
TOKEN_FILE="/tmp/spotify_access_${USER}"
ART_FILE="/tmp/sketchybar_spotify_art_${USER}.jpg"
API="https://api.spotify.com/v1"

ACCESS=""
EXPIRES_AT=0

kc() {
	security find-generic-password -s "$SERVICE" -a "$1" -w 2>/dev/null
}

# token_refresh: refresh-token grant; updates ACCESS/EXPIRES_AT + TOKEN_FILE.
# Returns non-zero if Keychain entries are missing or Spotify rejects them.
token_refresh() {
	_client_id=$(kc client_id) || return 1
	_client_secret=$(kc client_secret) || return 1
	_refresh_token=$(kc refresh_token) || return 1

	_netrc=$(mktemp) || return 1
	chmod 600 "$_netrc"
	printf 'machine accounts.spotify.com login %s password %s\n' \
		"$_client_id" "$_client_secret" > "$_netrc"
	_resp=$(printf 'grant_type=refresh_token&refresh_token=%s' "$_refresh_token" |
		curl -s --max-time 10 --netrc-file "$_netrc" \
			-X POST https://accounts.spotify.com/api/token -d @-)
	rm -f "$_netrc"

	_access=$(printf '%s' "$_resp" | jq -r '.access_token // empty' 2>/dev/null)
	[ -n "$_access" ] || return 1
	_expires=$(printf '%s' "$_resp" | jq -r '.expires_in // 3600' 2>/dev/null)
	_new_rt=$(printf '%s' "$_resp" | jq -r '.refresh_token // empty' 2>/dev/null)
	if [ -n "$_new_rt" ] && [ "$_new_rt" != "$_refresh_token" ]; then
		security add-generic-password -U -s "$SERVICE" -a refresh_token \
			-w "$_new_rt" >/dev/null 2>&1
	fi
	ACCESS=$_access
	EXPIRES_AT=$(( $(date +%s) + _expires - 60 ))
	umask 077
	printf '%s %s\n' "$ACCESS" "$EXPIRES_AT" > "$TOKEN_FILE"
	return 0
}

# token_ensure: memory token, else cached file token, else refresh
token_ensure() {
	_now=$(date +%s)
	if [ -n "$ACCESS" ] && [ "$EXPIRES_AT" -gt "$_now" ]; then
		return 0
	fi
	if [ -r "$TOKEN_FILE" ]; then
		_a=$(awk '{print $1}' "$TOKEN_FILE" 2>/dev/null)
		_e=$(awk '{print $2}' "$TOKEN_FILE" 2>/dev/null)
		if [ -n "$_a" ] && [ "${_e:-0}" -gt "$_now" ] 2>/dev/null; then
			ACCESS=$_a
			EXPIRES_AT=$_e
			return 0
		fi
	fi
	token_refresh
}

emit() {
	sketchybar --trigger spotify_update "INFO=$1"
}

emit_unavailable() {
	emit '{"source":"spotify_connect","available":false}'
}

# control CMD: one-shot transport command against the active device
cmd_control() {
	_cmd=$1
	case "$_cmd" in
		next) _ep="$API/me/player/next" ;;
		previous) _ep="$API/me/player/previous" ;;
		play) _ep="$API/me/player/play" ;;
		pause) _ep="$API/me/player/pause" ;;
		*) echo "unknown command: $_cmd"; exit 1 ;;
	esac
	token_ensure || { echo "spotify: not authorized"; exit 1; }
	_hdr=$(mktemp) || exit 1
	chmod 600 "$_hdr"
	printf 'Authorization: Bearer %s\n' "$ACCESS" > "$_hdr"
	_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
		-X POST -H @"$_hdr" "$_ep")
	if [ "$_code" = "401" ]; then
		token_refresh || { rm -f "$_hdr"; echo "spotify: re-auth failed"; exit 1; }
		printf 'Authorization: Bearer %s\n' "$ACCESS" > "$_hdr"
		_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
			-X POST -H @"$_hdr" "$_ep")
	fi
	rm -f "$_hdr"
	# 403/404: device restricted or no active device — do NOT retry
	if [ "$_code" = "403" ] || [ "$_code" = "404" ]; then
		echo "spotify: device rejected command ($_code)"
		exit 2
	fi
	echo "$_code"
}

# daemon: poll /v1/me/player, emit spotify_update events
daemon() {
	interval=20
	backoff=30
	last_state=""
	last_track_id=""
	auth_failures=0

	while :; do
		if ! token_ensure; then
			# no/broken credentials: dormant, but keep checking slowly so a
			# later `spotify_setup.sh` run is picked up without a bar reload
			if [ "$auth_failures" -eq 0 ]; then
				emit_unavailable
			fi
			auth_failures=$((auth_failures + 1))
			sleep 300
			continue
		fi
		auth_failures=0

		_hdr=$(mktemp) || exit 1
		chmod 600 "$_hdr"
		printf 'Authorization: Bearer %s\n' "$ACCESS" > "$_hdr"
		_hdrfile=$(mktemp)
		_resp=$(curl -s --max-time 10 -H @"$_hdr" -D "$_hdrfile" -w '\n%{http_code}' \
			"$API/me/player")
		rm -f "$_hdr"

		_code=${_resp##*$'\n'}
		_body=${_resp%$'\n'*}

		case "$_code" in
			200)
				backoff=30
				_playing=$(printf '%s' "$_body" | jq -r '.is_playing // false' 2>/dev/null)
				if [ "$_playing" = "true" ]; then
					interval=5
					# emit every poll while playing (drives popup progress)
					track_id=$(printf '%s' "$_body" | jq -r '.item.id // ""' 2>/dev/null)
					if [ "$track_id" != "$last_track_id" ]; then
						_art_url=$(printf '%s' "$_body" | jq -r '.item.album.images[0].url // empty' 2>/dev/null)
						if [ -n "$_art_url" ]; then
							curl -s --max-time 10 -o "$ART_FILE" "$_art_url"
						fi
						last_track_id=$track_id
					fi
					_payload=$(printf '%s' "$_body" | jq -c --arg f "$ART_FILE" '
						{source:"spotify_connect",
						 playing:(.is_playing // false),
						 title:(.item.name // ""),
						 artist:(.item.artists[0].name // ""),
						 album:(.item.album.name // ""),
						 elapsed:((.progress_ms // 0) / 1000),
						 duration:((.item.duration_ms // 0) / 1000),
						 device_name:(.device.name // "Spotify Connect"),
						 device_type:(.device.type // ""),
						 restricted:(.device.is_restricted // false),
						 disallows:(.actions.disallows // {}),
						 artwork_path:$f}' 2>/dev/null)
					[ -n "$_payload" ] && emit "$_payload"
					last_state="playing"
				else
					interval=20
					if [ "$last_state" != "paused" ]; then
						emit '{"source":"spotify_connect","playing":false}'
						last_state="paused"
						last_track_id=""
					fi
				fi
				;;
			204)
				# nothing playing anywhere on the account
				backoff=30
				interval=20
				if [ "$last_state" != "idle" ]; then
					emit '{"source":"spotify_connect","playing":false}'
					last_state="idle"
					last_track_id=""
				fi
				;;
			401)
				# token expired mid-flight: refresh once, retry immediately
				token_refresh || sleep 30
				;;
			429)
				_wait=$(awk 'tolower($1) == "retry-after:" {print $2}' "$_hdrfile" 2>/dev/null)
				case "${_wait:-}" in '' | *[!0-9]*) _wait=30 ;; esac
				[ "$_wait" -gt 120 ] && _wait=120
				sleep "$_wait"
				;;
			000)
				# network failure / timeout: local media is unaffected; retry later
				sleep "$backoff"
				backoff=$((backoff * 2))
				[ "$backoff" -gt 300 ] && backoff=300
				;;
			*)
				# 5xx / unexpected: back off
				sleep "$backoff"
				backoff=$((backoff * 2))
				[ "$backoff" -gt 300 ] && backoff=300
				;;
		esac
		rm -f "$_hdrfile" 2>/dev/null
		sleep "$interval"
	done
}

case "${1:-}" in
	control)
		cmd_control "$2"
		;;
	"")
		daemon
		;;
	*)
		echo "usage: spotify_connect.sh [control next|previous|play|pause]"
		exit 1
		;;
esac
