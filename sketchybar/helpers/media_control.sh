#!/bin/sh

# SB-fix: sketchybar's native media_change event does not fire on macOS 26
# (MediaRemote lockdown — `nowplaying-cli get` returns nothing). media-control
# works (verified: `media-control test` exit 0), so stream its JSON and re-emit
# each update as a media_update event that SbarLua parses into env.INFO.
#
# Spawned from items/media.lua (same pattern as cpu_load/network_load).
#
# Event model (verified against media-control 0.7.7):
#   - stream payloads are FULL on track/session changes, SPARSE on session
#     activation/resume ({playing, bundleIdentifier}, no metadata) and {} on
#     session end. The stream is SILENT during steady playback — browsers
#     (Brave/YouTube etc.) only emit on changes.
#   - Therefore a 10s co-poll re-emits a full snapshot while playing=true and
#     the whole-second position changed: keeps the widget's freshness window
#     alive, ticks popup progress, and self-heals a dead stream. Paused media
#     never triggers poller emits.
#
# Perf/UX notes:
#  - --allow-missing-title: media with no title (e.g. playback stopped) is
#    still emitted, so the widget can clear itself instead of going stale.
#  - artworkData is only base64-decoded + written when its checksum changes
#    (~1Hz stream updates would otherwise re-decode ~800KB every second).
#  - cached artwork is NEVER cleared in the helper: empty/{} payloads can be
#    spurious under media-control's multi-session arbitration, and a stale
#    file is harmless (popup hidden, next track overwrites). Writes are
#    atomic (tmp + mv) so a raced decode can never truncate the file.

ARTWORK_FILE="/tmp/sketchybar_media_artwork_${USER}.jpg"
last_art_sum="__none__"

emit() {
	/opt/homebrew/bin/sketchybar --trigger media_update "INFO=$1"
}

# artwork handling + re-emit, shared by the stream loop and the poller
emit_payload() {
	_p=$1

	art_b64=$(printf '%s' "$_p" | jq -r '.artworkData // empty' 2>/dev/null)
	if [ -n "$art_b64" ]; then
		art_sum=$(printf '%s' "$art_b64" | cksum | awk '{print $1 "." $2}')
		if [ "$art_sum" != "$last_art_sum" ]; then
			# atomic write: decode to a temp file, then rename. A failed or
			# raced decode can never truncate the previous artwork to 0 bytes.
			if printf '%s' "$art_b64" | base64 --decode > "$ARTWORK_FILE.tmp" 2>/dev/null; then
				mv -f "$ARTWORK_FILE.tmp" "$ARTWORK_FILE"
			fi
			last_art_sum=$art_sum
		fi
	fi
	# NOTE: no artwork clearing here. The old "empty payload = session end"
	# heuristic truncated the artwork to 0 bytes whenever media-control's
	# multi-session arbitration emitted a spurious {} while another app was
	# still playing. Stale artwork is harmless: the popup is unreachable
	# while the widget is hidden and the next track overwrites the file.

	# The JSON is passed as ONE argv element ("INFO=..."), so spaces and
	# double quotes inside it survive without any escaping. sketchybar only
	# decodes artwork for its INTERNAL media_change event (dead on macOS 26),
# so artwork is decoded here and passed by path.
	_p=$(printf '%s' "$_p" | jq -c 'del(.artworkData) + {artwork_path: $f}' --arg f "$ARTWORK_FILE")
	emit "$_p"
}

# "refresh" mode: emit one full snapshot now (used by the paused-state watchdog
# in items/media.lua to self-heal missed stream events, e.g. slow resumes)
if [ "$1" = "refresh" ]; then
	payload=$(media-control get 2>/dev/null)
	[ -n "$payload" ] && emit_payload "$payload"
	exit 0
fi

# STREAM: event-driven path
media-control stream --no-diff --allow-missing-title --debounce=250 | while IFS= read -r line; do
	[ -n "$line" ] || continue
	# stream emits an envelope {"type":"data","diff":...,"payload":{...}};
	# unwrap .payload and skip empty lines (empty {} payloads ARE passed on so
	# the widget can react to "nothing playing")
	payload=$(printf '%s' "$line" | jq -c '.payload // empty' 2>/dev/null)
	[ -n "$payload" ] || continue
	emit_payload "$payload"
done &

# POLL: keep-alive for silent steady playback (see header). One `get` per
# 10s while playing; emits only when the whole-second position changed.
last_poll_elapsed="__none__"
while :; do
	sleep 10
	payload=$(media-control get 2>/dev/null)
	[ -n "$payload" ] || continue
	playing=$(printf '%s' "$payload" | jq -r '.playing // false' 2>/dev/null)
	[ "$playing" = "true" ] || continue
	el=$(printf '%s' "$payload" | jq -r '.elapsedTime // 0 | floor' 2>/dev/null)
	case "${el:-}" in '' | *[!0-9]*) continue ;; esac
	[ "$el" = "$last_poll_elapsed" ] && continue
	last_poll_elapsed=$el
	emit_payload "$payload"
done
