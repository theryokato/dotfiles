#!/bin/sh

# SB-fix: sketchybar's native media_change event does not fire on macOS 26
# (MediaRemote lockdown — `nowplaying-cli get` returns nothing). media-control
# works (verified: `media-control test` exit 0), so stream its JSON and re-emit
# each update as a media_update event that SbarLua parses into env.INFO.
#
# Spawned from items/media.lua (same pattern as cpu_load/network_load).
#
# Perf/UX notes:
#  - --allow-missing-title: media with no title (e.g. playback stopped) is
#    still emitted, so the widget can clear itself instead of going stale.
#  - artworkData is only base64-decoded + written when its checksum changes
#    (~1Hz stream updates would otherwise re-decode ~800KB every second).

ARTWORK_FILE="/tmp/sketchybar_media_artwork_${USER}.jpg"
last_art_sum="__none__"

# "refresh" mode: emit one full snapshot now (used by the paused-state watchdog
# in items/media.lua to self-heal missed stream events, e.g. slow resumes)
if [ "$1" = "refresh" ]; then
	payload=$(media-control get 2>/dev/null | jq -c 'del(.artworkData) + {artwork_path: $f}' --arg f "$ARTWORK_FILE" 2>/dev/null)
	[ -n "$payload" ] && /opt/homebrew/bin/sketchybar --trigger media_update "INFO=$payload"
	exit 0
fi

media-control stream --no-diff --allow-missing-title --debounce=250 | while IFS= read -r line; do
	[ -n "$line" ] || continue
	# stream emits an envelope {"type":"data","diff":...,"payload":{...}};
	# unwrap .payload and skip empty lines (empty {} payloads ARE passed on so
	# the widget can react to "nothing playing")
	payload=$(printf '%s' "$line" | jq -c '.payload // empty' 2>/dev/null)
	[ -n "$payload" ] || continue

	# sketchybar only decodes artwork for its INTERNAL media_change event,
	# which is dead on macOS 26 — external media_change triggers are swallowed.
	# So we use a custom event and decode the artwork to a file ourselves;
	# base64 alphabet is shell-safe and it goes through a pipe (no ARG_MAX issues).
	art_b64=$(printf '%s' "$payload" | jq -r '.artworkData // empty' 2>/dev/null)
	if [ -n "$art_b64" ]; then
		art_sum=$(printf '%s' "$art_b64" | cksum | awk '{print $1 "." $2}')
		if [ "$art_sum" != "$last_art_sum" ]; then
			printf '%s' "$art_b64" | base64 --decode > "$ARTWORK_FILE" 2>/dev/null \
				|| : > "$ARTWORK_FILE"
			last_art_sum=$art_sum
		fi
	elif [ "$last_art_sum" != "__none__" ]; then
		# track without artwork: clear the cached file exactly once
		: > "$ARTWORK_FILE"
		last_art_sum="__none__"
	fi

	payload=$(printf '%s' "$payload" | jq -c 'del(.artworkData) + {artwork_path: $f}' --arg f "$ARTWORK_FILE")

	# The JSON is passed as ONE argv element ("INFO=..."), so spaces and double
	# quotes inside it survive without any escaping.
	/opt/homebrew/bin/sketchybar --trigger media_update "INFO=$payload"
done
