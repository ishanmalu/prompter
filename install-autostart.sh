#!/usr/bin/env bash
# Keep the prompter's file server running so the address is always there, like
# any other bookmark. Undo with ./uninstall-autostart.sh
#
#   ./install-autostart.sh         # default port 8080
#   ./install-autostart.sh 9000    # different port
#
# This starts server.py -- the static server plus the /upload endpoint that
# "Send to Mac" posts takes to. It stays bound to 127.0.0.1 because
# `tailscale serve` is what puts it on the tailnet, and serve needs a real
# certificate in front of it — getUserMedia refuses a plain-HTTP origin, so
# binding straight to the tailnet IP would give you a page with a dead camera.
# The serve config survives reboots on its own; this is the half that doesn't.
set -e
cd "$(dirname "$0")"
DIR="$(pwd)"
PORT="${1:-8080}"

PLIST="$HOME/Library/LaunchAgents/dev.ishanmalu.prompter.plist"
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__DIR__|$DIR|g" -e "s|__PORT__|$PORT|g" autostart.plist > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Prompter will now start at login on 127.0.0.1:$PORT."

if tailscale serve status 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
  DNSNAME="$(tailscale status --json 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
  [ -n "$DNSNAME" ] && echo "Bookmark:  https://$DNSNAME/"
else
  echo
  echo "Nothing is serving port $PORT on the tailnet yet. To expose it:"
  echo "  tailscale serve --bg $PORT"
fi
