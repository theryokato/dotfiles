#!/bin/sh

# One-time Spotify authorization for the SketchyBar Connect integration.
#
# Asks for your Spotify developer app credentials locally (secret input is
# hidden), opens a browser for consent, catches the OAuth code on a
# LOOPBACK-ONLY callback (127.0.0.1:4181, never exposed publicly) and stores
# client_id / client_secret / refresh_token in the macOS Keychain (service
# "sketchybar-spotify"). Nothing is written to dotfiles or logs.
#
# Requested scopes (minimum needed):
#   user-read-playback-state      see active Connect device + state
#   user-read-currently-playing   currently playing track
#   user-modify-playback-state    popup transport controls for Connect devices

SERVICE="sketchybar-spotify"
PORT=4181
REDIRECT="http://127.0.0.1:${PORT}/callback"
SCOPES="user-read-playback-state user-read-currently-playing user-modify-playback-state"
CODE_FILE="/tmp/spotify_auth_code.$$"

printf 'Spotify Client ID: '
read -r CLIENT_ID
printf 'Spotify Client Secret (input hidden): '
stty -echo 2>/dev/null
read -r CLIENT_SECRET
stty echo 2>/dev/null
printf '\n'
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
	echo "Missing credentials. Get them from https://developer.spotify.com/dashboard"
	echo "(your app must have Redirect URI: $REDIRECT)"
	exit 1
fi

rm -f "$CODE_FILE"

# loopback-only one-shot callback server
python3 - "$CODE_FILE" "$PORT" <<'PY' &
import http.server
import pathlib
import sys
import urllib.parse

code_file, port = sys.argv[1], int(sys.argv[2])


class Handler(http.server.BaseHTTPRequestHandler):
	def do_GET(self):
		qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
		code = qs.get("code", [""])[0]
		try:
			pathlib.Path(code_file).write_text(code)
		except Exception:
			pass
		self.send_response(200)
		self.send_header("Content-Type", "text/html; charset=utf-8")
		self.end_headers()
		self.wfile.write(
			b"<html><body style='font-family:-apple-system,sans-serif;padding:48px'>"
			b"<h2>&#10003; Spotify authorized</h2>"
			b"<p>You can close this tab and return to the terminal.</p></body></html>"
		)

	def log_message(self, *args):
		pass


http.server.HTTPServer(("127.0.0.1", port), Handler).handle_request()
PY
SERVER_PID=$!
sleep 1

AUTH_URL="https://accounts.spotify.com/authorize?client_id=${CLIENT_ID}&response_type=code&redirect_uri=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$REDIRECT")&scope=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))' "$SCOPES")"
open "$AUTH_URL"
echo "Waiting for authorization in your browser (up to 120s)..."

i=0
while [ "$i" -lt 120 ] && [ ! -s "$CODE_FILE" ]; do
	sleep 1
	i=$((i + 1))
done
kill "$SERVER_PID" 2>/dev/null
if [ ! -s "$CODE_FILE" ]; then
	echo "Authorization timed out or was cancelled. No credentials were stored."
	rm -f "$CODE_FILE"
	exit 1
fi
CODE=$(cat "$CODE_FILE")
rm -f "$CODE_FILE"

# exchange the authorization code (credentials via 0600 netrc file, not argv)
_NETRC=$(mktemp) || exit 1
chmod 600 "$_NETRC"
printf 'machine accounts.spotify.com login %s password %s\n' "$CLIENT_ID" "$CLIENT_SECRET" > "$_NETRC"
RESP=$(printf 'grant_type=authorization_code&code=%s&redirect_uri=%s' "$CODE" "$REDIRECT" |
	curl -s --max-time 15 --netrc-file "$_NETRC" \
		-X POST https://accounts.spotify.com/api/token -d @-)
rm -f "$_NETRC"

REFRESH=$(printf '%s' "$RESP" | jq -r '.refresh_token // empty' 2>/dev/null)
if [ -z "$REFRESH" ]; then
	echo "Token exchange failed:"
	printf '%s\n' "$RESP" | jq -r '.error_description // .error // .' 2>/dev/null
	exit 1
fi

security add-generic-password -U -s "$SERVICE" -a client_id -w "$CLIENT_ID"
security add-generic-password -U -s "$SERVICE" -a client_secret -w "$CLIENT_SECRET"
security add-generic-password -U -s "$SERVICE" -a refresh_token -w "$REFRESH"

echo "Spotify Connect integration ready."
echo "Credentials + refresh token are stored in the macOS Keychain (service: $SERVICE)."
