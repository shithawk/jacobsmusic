#!/bin/bash
# Expose Jacob's Music on Tailscale (tailnet only).
#   Jacob's → https://<machine>.<tailnet>.ts.net:8444/  (Caddy :8092)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QR="$ROOT/images/jacobsmusic-tailscale-qr.png"

echo "Tailscale Serve: Jacob's on :8092 (HTTPS :8444)"
tailscale serve --bg --https=8444 "http://127.0.0.1:8092"
tailscale serve status

if ! lsof -iTCP:8092 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Starting Caddy for Jacob's (8092)…"
  (cd "$ROOT" && caddy run --config Caddyfile) &
  sleep 1
fi

DNS="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
if [[ -n "$DNS" ]]; then
  URL="https://${DNS}:8444/"
  python3 - "$URL" "$QR" <<'PY'
import sys
from pathlib import Path

import qrcode

url, dest = sys.argv[1], Path(sys.argv[2])
dest.parent.mkdir(parents=True, exist_ok=True)
qrcode.make(url, box_size=8, border=2).save(dest)
print(f"QR saved: {dest}")
PY
  echo ""
  echo "Jacob's on phone or tablet (Tailscale on, same account):"
  echo "  URL: $URL"
  echo "  QR:  $QR"
  echo ""
  echo "  iPhone: Safari → open URL → Share → Add to Home Screen."
  echo "  Android: Chrome → open URL → ⋮ → Install app or Add to Home screen."
  echo "  Then use + Add music to download the library on Wi‑Fi."
fi