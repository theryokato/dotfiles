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
