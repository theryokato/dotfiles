#!/bin/bash
# Notify simple-bar-server to refresh simple-bar's AeroSpace spaces widget.
# Usage: simple-bar-refresh.sh [workspace]
#
# Uses bash's built-in /dev/tcp instead of spawning curl (~35ms faster per
# event). Optional $1 = focused workspace name (passed by AeroSpace's
# exec-on-workspace-change via $AEROSPACE_FOCUSED_WORKSPACE); when given,
# simple-bar applies the focused-workspace highlight optimistically before
# its background refetch.

exec 3<>/dev/tcp/127.0.0.1/7776 || exit 0

path="/aerospace/spaces/refresh"
if [ -n "$1" ]; then
  path="$path?space=$1"
fi

printf 'GET %s HTTP/1.0\r\nHost: localhost\r\n\r\n' "$path" >&3
cat <&3 > /dev/null
