#!/bin/bash
set -euo pipefail
LOG="/Users/jacobward/jacobsmusic/scripts/_funnel-once.log"
exec >"$LOG" 2>&1
echo "=== $(date) ==="
which tailscale
/usr/local/bin/tailscale version || true
/usr/local/bin/tailscale status || true
curl -sf --max-time 3 "http://127.0.0.1:8095/" >/dev/null && echo "caddy:ok" || echo "caddy:DOWN"
/usr/local/bin/tailscale funnel --bg --yes --https=10000 "http://127.0.0.1:8095"
echo "funnel_exit:$?"
/usr/local/bin/tailscale funnel status || true
curl -sk --max-time 15 -o /dev/null -w "funnel_http:%{http_code}\n" "https://jacobs-macbook-air.tailaac76e.ts.net:10000/" || echo "funnel_curl_fail"
echo DONE
