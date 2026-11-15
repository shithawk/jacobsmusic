#!/bin/bash
# Same-Wi-Fi guest install: HTTPS on LAN :8445 (no Tailscale on the phone).
# Keeps Tailscale path on 127.0.0.1:8092. QR → https://<lan-ip>:8445/?guest=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${GUEST_PORT:-8445}"
QR="$ROOT/images/jacobsmusic-guest-qr.png"

lan_ip() {
  local iface ip
  for iface in en0 en1 bridge0; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

if ! IP="$(lan_ip)"; then
  echo "Could not find a Wi-Fi/LAN IP (en0/en1). Connect to Wi-Fi and retry." >&2
  exit 1
fi

URL="https://${IP}:${PORT}/?guest=1"

python3 - "$URL" "$QR" <<'PY'
import sys
from pathlib import Path

import qrcode

url, dest = sys.argv[1], Path(sys.argv[2])
dest.parent.mkdir(parents=True, exist_ok=True)
img = qrcode.make(url, box_size=8, border=2)
img.save(dest)
print(f"QR saved: {dest}")
PY

echo ""
echo "Guest install (same Wi-Fi, Android/iPhone)"
echo "  URL:  $URL"
echo "  QR:   $QR"
echo ""
echo "On the phone:"
echo "  1. Connect to the same Wi-Fi as this Mac."
echo "  2. Scan the QR (or type the URL in Chrome)."
echo "  3. If Chrome warns about the certificate: Advanced → Proceed."
echo "  4. Install the app (Chrome ⋮ → Install app)."
echo "  5. + Add music → download on Wi-Fi (large; can take a while)."
echo ""
if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PORT is already in use. Stop the other Caddy first." >&2
  exit 1
fi
if ! lsof -iTCP:8092 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Note: nothing on :8092 yet — Tailscale :8444 will not work until this Caddy is up."
fi
echo "Starting Caddy (guest mode). Ctrl+C to stop."
echo "For daily use without LAN exposure, use: caddy run --config Caddyfile"
echo ""

cd "$ROOT"
exec caddy run --config Caddyfile.guest