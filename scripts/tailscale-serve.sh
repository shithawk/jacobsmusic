#!/bin/bash
# Expose Jacob's Music on Tailscale (tailnet only).
#   Jacob's → https://<machine>.<tailnet>.ts.net:8444/  (Caddy :8092)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Tailscale Serve: Jacob's on :8092 (HTTPS :8444)"
tailscale serve --bg --https=8444 "http://127.0.0.1:8092"
tailscale serve status

if ! lsof -iTCP:8092 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Starting Caddy for Jacob's (8092)…"
  (cd "$ROOT" && caddy run --config Caddyfile) &
fi

DNS="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
if [[ -n "$DNS" ]]; then
  echo ""
  echo "Jacob's on phone or tablet:"
  echo "  1. Install Tailscale, sign in to the same account, turn VPN on."
  echo "  2. Safari → https://${DNS}:8444/"
  echo "  3. Share → Add to Home Screen."
fi