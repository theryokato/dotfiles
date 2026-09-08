#!/bin/sh

# CAVA → SketchyBar visualizer pump.
#
# Spawned exactly ONCE by items/media.lua (which pkills stale instances first
# via the '[c]ava_stream' bracket pattern, so reloads never duplicate us).
#
# Design notes:
#  - cava does all DSP work; this script only forwards frames.
#  - ONE combined `sketchybar --set ...` invocation per frame (30 fps, 8 bars).
#  - Freeze file: when it exists, frames are NOT applied. items/media.lua
#    touches/removes it on pause/resume so the visualizer freezes instead of
#    pretending audio is active while paused (checked with the shell builtin
#    `test`, i.e. no extra process per frame).

PATH="/opt/homebrew/bin:$PATH"
FREEZE="/tmp/sketchybar_cava_frozen_${USER}"

# Wait briefly for the media.vis items (items/media.lua spawns us BEFORE it
# creates them in the same load). If they never appear -- e.g. the Lua config
# failed mid-load -- exit ONCE instead of erroring per frame at 30fps
# (~21k 'Item not found' lines per session).
n=0
while [ "$n" -lt 20 ]; do
	sketchybar --query media.vis1 >/dev/null 2>&1 && break
	n=$((n + 1))
	sleep 0.5
done
if [ "$n" -ge 20 ]; then
	echo "cava_stream: media.vis items missing after 10s, exiting" >&2
	exit 0
fi

cava -p "$HOME/.config/sketchybar/helpers/cava.conf" | while IFS= read -r frame; do
	[ -f "$FREEZE" ] && continue

	# skip identical frames (e.g. all-zero silence) — no sketchybar traffic
	[ "$frame" = "$last_frame" ] && continue
	last_frame=$frame

	# frame: "3 7 1 0 5 8 8 2 " — one 0..8 value per bar
	set -- $frame
	[ $# -eq 8 ] || continue

	sketchybar \
		--set media.vis1 background.height=$((2 + $1 * 3)) \
		--set media.vis2 background.height=$((2 + $2 * 3)) \
		--set media.vis3 background.height=$((2 + $3 * 3)) \
		--set media.vis4 background.height=$((2 + $4 * 3)) \
		--set media.vis5 background.height=$((2 + $5 * 3)) \
		--set media.vis6 background.height=$((2 + $6 * 3)) \
		--set media.vis7 background.height=$((2 + $7 * 3)) \
		--set media.vis8 background.height=$((2 + $8 * 3))
done
