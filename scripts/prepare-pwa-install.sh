#!/bin/bash
# Rebuild catalogs, ensure Caddy + Tailscale Serve, refresh install QR for Android PWA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Jacob's Music — prepare PWA install (Android / Tailscale) =="
echo ""

echo "1/4 Rebuild MP3 catalog…"
bash "$ROOT/scripts/make-catalog.sh"

echo "2/4 Rebuild YouTube catalog…"
bash "$ROOT/scripts/make-youtube-catalog.sh"

echo "3/4 Local Caddy (:8092)…"
if ! curl -sf --max-time 3 "http://127.0.0.1:8092/" >/dev/null; then
  mkdir -p "$ROOT/caddy-data"
  if [[ -f "$ROOT/caddy-data/caddy.pid" ]]; then
    oldpid="$(cat "$ROOT/caddy-data/caddy.pid")"
    kill "$oldpid" 2>/dev/null || true
    rm -f "$ROOT/caddy-data/caddy.pid"
  fi
  nohup caddy run --config "$ROOT/Caddyfile" >>"$ROOT/caddy-data/caddy.log" 2>&1 &
  echo $! >"$ROOT/caddy-data/caddy.pid"
  sleep 1
  if ! curl -sf --max-time 3 "http://127.0.0.1:8092/" >/dev/null; then
    echo "Caddy failed to start. See $ROOT/caddy-data/caddy.log" >&2
    exit 1
  fi
fi
echo "  OK http://127.0.0.1:8092/"

echo "4/4 Tailscale Serve (:8444 → :8092)…"
bash "$ROOT/scripts/tailscale-serve.sh"

MP3_COUNT="$(python3 -c "import json; print(len(json.load(open('$ROOT/music/catalog.json'))))" 2>/dev/null || echo "?")"
YT_COUNT="$(python3 -c "import json; print(len(json.load(open('$ROOT/youtube/catalog.json'))))" 2>/dev/null || echo "?")"
BYTES="$(python3 -c "import json; c=json.load(open('$ROOT/music/catalog.json')); print(sum(x.get('bytes',0) for x in c))" 2>/dev/null || echo 0)"
MB=$((BYTES / 1024 / 1024))

DNS="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"

echo ""
echo "Catalog: ${MP3_COUNT} songs on Mac (~${MB} MB), ${YT_COUNT} YouTube entries in videos list."
echo ""
if [[ -n "$DNS" ]]; then
  echo "Tailscale (Android / phone with Tailscale on, same account):"
  echo "  https://${DNS}:8444/"
  echo "  QR:  $ROOT/images/jacobsmusic-tailscale-qr.png"
  echo ""
  echo "  Chrome → open URL → ⋮ → Install app (or Update if already installed)."
  echo "  Then + Add music → Download all on Wi‑Fi."
fi
echo ""
echo "Same Wi‑Fi without Tailscale:  ./scripts/guest-serve.sh  (QR in images/jacobsmusic-guest-qr.png)"
echo "Keep this Mac awake while the phone downloads."