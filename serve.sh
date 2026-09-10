#!/usr/bin/env bash
# Serve the prompter on your tailnet over HTTPS.
#
#   ./serve.sh          # start on :8080, expose via tailscale serve
#   ./serve.sh 9000     # different port
#   ./serve.sh --stop   # tear down the tailscale serve config
#
# Why the TLS dance: getUserMedia only works in a secure context. localhost
# counts, a bare http://100.x.x.x does not. `tailscale serve` fronts the local
# server with a real *.ts.net certificate, which makes Chrome happy on every
# device in the tailnet.

set -euo pipefail
cd "$(dirname "$0")"

PORT="${1:-8080}"

if [[ "${1:-}" == "--stop" ]]; then
  tailscale serve --https=443 off 2>/dev/null || true
  echo "tailscale serve turned off."
  exit 0
fi

command -v tailscale >/dev/null || { echo "tailscale not found in PATH." >&2; exit 1; }

if ! tailscale status >/dev/null 2>&1; then
  echo "Tailscale isn't running. Start it, then re-run this script." >&2
  exit 1
fi

# Static file server. python3 ships with macOS.
python3 -m http.server "$PORT" --bind 127.0.0.1 >/tmp/prompter-http.log 2>&1 &
HTTP_PID=$!
trap 'kill "$HTTP_PID" 2>/dev/null || true' EXIT

sleep 1
kill -0 "$HTTP_PID" 2>/dev/null || { echo "Local server failed to start:" >&2; cat /tmp/prompter-http.log >&2; exit 1; }

echo "Local server on http://127.0.0.1:$PORT (pid $HTTP_PID)"

# Foreground `tailscale serve` prints the public URL and holds until Ctrl-C.
echo "Exposing over the tailnet…"
tailscale serve --bg "$PORT"
tailscale serve status

DNSNAME="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
if [[ -n "$DNSNAME" ]]; then
  echo
  echo "  Open:  https://$DNSNAME/"
  echo
fi
echo "Ctrl-C to stop the file server. Run './serve.sh --stop' to remove the serve config."

wait "$HTTP_PID"
