#!/bin/bash
# Double-click to restore Samantha public Funnel :10000 → local Caddy :8095
cd "$(dirname "$0")"
set -euo pipefail
echo "Checking Caddy on :8095…"
if ! curl -sf --max-time 3 "http://127.0.0.1:8095/" >/dev/null; then
  echo "Starting Caddy keep-up…"
  if [[ -x /Users/jacobward/samanthasmusic/scripts/caddy-keep-up.sh ]]; then
    nohup /Users/jacobward/samanthasmusic/scripts/caddy-keep-up.sh >/tmp/samantha-caddy-keep-up.log 2>&1 &
    sleep 2
  fi
fi
curl -sf --max-time 3 "http://127.0.0.1:8095/" >/dev/null || {
  echo "Caddy still down on :8095. Start Samantha Caddy first."
  read -r -p "Press Enter to close…"
  exit 1
}
echo "Enabling Tailscale Funnel :10000…"
/usr/local/bin/tailscale funnel --bg --yes --https=10000 "http://127.0.0.1:8095"
/usr/local/bin/tailscale funnel status || true
echo
echo "Probe:"
curl -sk --max-time 15 -o /dev/null -w "  https://jacobs-macbook-air.tailaac76e.ts.net:10000/ → HTTP %{http_code}\n" \
  "https://jacobs-macbook-air.tailaac76e.ts.net:10000/" || echo "  probe failed"
echo
echo "Done. Reopen Samantha's player on :10000 (close and reopen the PWA if it was open)."
read -r -p "Press Enter to close…"
