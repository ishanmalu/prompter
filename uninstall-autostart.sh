#!/usr/bin/env bash
set -e
PLIST="$HOME/Library/LaunchAgents/dev.ishanmalu.prompter.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "Autostart removed. The tailscale serve config is untouched;"
echo "run 'tailscale serve --https=443 off' if you want that gone too."
