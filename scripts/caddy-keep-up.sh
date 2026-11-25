#!/bin/bash
# Keep Jacob's Music Caddy on :8092 and Tailscale HTTPS :8444 pointed at it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/caddy-data"

# Suggest API (Last.fm + SoundCloud) for Artists page.
bash "$ROOT/scripts/ensure-suggest-api.sh" >/dev/null 2>&1 || true

# Ensure Tailscale Serve proxies here. Ignore failures if Tailscale is off.
tailscale serve --bg --https=8444 http://127.0.0.1:8092 >/dev/null 2>&1 || true

exec /opt/homebrew/bin/caddy run --config "$ROOT/Caddyfile"
