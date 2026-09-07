#!/bin/sh

# SB-fix: sketchybar's native media_change event does not fire on macOS 26
# (MediaRemote lockdown — `nowplaying-cli get` returns nothing). media-control
# works (verified: `media-control test` exit 0), so stream its JSON and re-emit
# each update as a media_change event that SbarLua parses into env.INFO.
#
# Spawned from items/media.lua (same pattern as cpu_load/network_load).

media-control stream --no-diff --debounce=250 | while IFS= read -r line; do
	[ -n "$line" ] || continue
	# stream emits an envelope {"type":"data","diff":...,"payload":{...}};
	# unwrap .payload and skip empty/no-payload lines
	payload=$(printf '%s' "$line" | jq -c '.payload // empty' 2>/dev/null)
	[ -n "$payload" ] || continue
	[ "$payload" = "{}" ] && continue

	# sketchybar only decodes artwork for its INTERNAL media_change event,
	# which is dead on macOS 26 — external media_change triggers are swallowed.
	# So we use a custom event and decode the artwork to a file ourselves;
	# base64 alphabet is shell-safe and it goes through a pipe (no ARG_MAX issues).
	artwork_file="/tmp/sketchybar_media_artwork_${USER}.jpg"
	printf '%s' "$payload" | jq -r '.artworkData // empty' | base64 --decode > "$artwork_file" 2>/dev/null \
		|| : > "$artwork_file"

	payload=$(printf '%s' "$payload" | jq -c 'del(.artworkData) + {artwork_path: $f}' --arg f "$artwork_file")

	# The JSON is passed as ONE argv element ("INFO=..."), so spaces and double
	# quotes inside it survive without any escaping.
	/opt/homebrew/bin/sketchybar --trigger media_update "INFO=$payload"
done
