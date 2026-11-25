#!/bin/bash
# Start Jacob's suggest API on :8096 if needed (Last.fm + SoundCloud).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/caddy-data"
PIDFILE="$ROOT/caddy-data/suggest-api.pid"
LOG="$ROOT/caddy-data/suggest-api.log"
ENVFILE="$ROOT/suggest.env"

if [[ -f "$ENVFILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENVFILE"
  set +a
fi

if curl -sf --max-time 2 "http://127.0.0.1:8096/health" >/dev/null; then
  echo "  Suggest API OK http://127.0.0.1:8096/"
  exit 0
fi

if [[ -f "$PIDFILE" ]]; then
  oldpid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "${oldpid:-}" ]]; then
    kill "$oldpid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
fi

nohup env PYTHONUNBUFFERED=1 python3 -u "$ROOT/scripts/suggest-api.py" >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
sleep 1

if curl -sf --max-time 3 "http://127.0.0.1:8096/health" >/dev/null; then
  echo "  Suggest API started http://127.0.0.1:8096/"
  if [[ ! -f "$ENVFILE" ]]; then
    echo "  Tip: create $ENVFILE with LASTFM_API_KEY=... and SOUNDCLOUD_CLIENT_ID=..."
  fi
  exit 0
fi

echo "  Suggest API failed to start. See $LOG" >&2
exit 1
