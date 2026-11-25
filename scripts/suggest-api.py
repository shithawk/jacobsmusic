#!/usr/bin/env python3
"""Local suggest API for Jacob's Music: Last.fm similar artists + SoundCloud tracks.

Env (load from suggest.env next to repo root, or process environment):
  LASTFM_API_KEY
  SOUNDCLOUD_CLIENT_ID

Listens on 127.0.0.1:8096 — Caddy proxies /api/suggest-artists here.
"""
from __future__ import annotations

import json
import os
import re
import socket
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# macOS can hang inside HTTPServer bind via socket.getfqdn() when DNS is slow.
socket.getfqdn = lambda name="": (name or "localhost")  # type: ignore[assignment]


def ssl_context() -> ssl.SSLContext:
    """Python.org macOS builds often lack certs; prefer certifi, else system, else unverified."""
    try:
        import certifi  # type: ignore

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        pass
    try:
        return ssl.create_default_context()
    except Exception:
        return ssl._create_unverified_context()


SSL_CTX = ssl_context()

ROOT = Path(__file__).resolve().parents[1]
HOST = "127.0.0.1"
PORT = 8096
CACHE_TTL = 6 * 60 * 60
UA = "JacobsMusicSuggest/1.0"

_cache: dict[str, tuple[float, object]] = {}
_cache_lock = threading.Lock()
_client_id_lock = threading.Lock()
_runtime_client_id = ""


def load_env_file() -> None:
    path = ROOT / "suggest.env"
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def cache_get(key: str):
    with _cache_lock:
        row = _cache.get(key)
        if not row:
            return None
        expires, value = row
        if time.time() > expires:
            _cache.pop(key, None)
            return None
        return value


def cache_set(key: str, value: object) -> None:
    with _cache_lock:
        _cache[key] = (time.time() + CACHE_TTL, value)


def http_open(url: str, timeout: float = 12.0):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    return urllib.request.urlopen(req, timeout=timeout, context=SSL_CTX)


def http_json(url: str, timeout: float = 12.0):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout, context=SSL_CTX) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def lastfm_key() -> str:
    return (os.environ.get("LASTFM_API_KEY") or "").strip()


def soundcloud_client_id() -> str:
    global _runtime_client_id
    env = (os.environ.get("SOUNDCLOUD_CLIENT_ID") or "").strip()
    if env:
        return env
    with _client_id_lock:
        if _runtime_client_id:
            return _runtime_client_id
        discovered = discover_soundcloud_client_id()
        if discovered:
            _runtime_client_id = discovered
        return _runtime_client_id


def discover_soundcloud_client_id() -> str:
    """Best-effort: pull a public client_id from SoundCloud web assets."""
    try:
        with http_open("https://soundcloud.com", timeout=8) as resp:
            html = resp.read().decode("utf-8", errors="replace")
        patterns = (
            r'client_id["\']?\s*[:=]\s*["\']([a-zA-Z0-9]{32})["\']',
            r'clientId["\']?\s*[:=]\s*["\']([a-zA-Z0-9]{32})["\']',
            r'client_id=([a-zA-Z0-9]{32})',
            r'["\']clientId["\']\s*:\s*["\']([a-zA-Z0-9]{32})["\']',
        )
        for pattern in patterns:
            match = re.search(pattern, html)
            if match:
                return match.group(1)
        scripts = re.findall(r'src="(https://a-v2\.sndcdn\.com/assets/[^"]+\.js)"', html)
        # Prefer larger webpack chunks (client id often lives there).
        scripts = sorted(set(scripts), key=lambda url: url, reverse=True)
        for src in scripts:
            try:
                with http_open(src, timeout=12) as sresp:
                    body = sresp.read().decode("utf-8", errors="replace")
                for pattern in patterns:
                    match = re.search(pattern, body)
                    if match:
                        return match.group(1)
                near = re.search(r'client(?:_id|Id)[^a-zA-Z0-9]{0,24}([a-zA-Z0-9]{32})', body)
                if near:
                    return near.group(1)
            except Exception:
                continue
    except Exception:
        return ""
    return ""


def lastfm_similar(artist: str, limit: int = 20) -> list[dict]:
    key = lastfm_key()
    if not key or not artist:
        return []
    cache_key = "lfm:" + artist.lower()
    cached = cache_get(cache_key)
    if cached is not None:
        return cached  # type: ignore[return-value]
    params = urllib.parse.urlencode(
        {
            "method": "artist.getsimilar",
            "artist": artist,
            "api_key": key,
            "format": "json",
            "limit": str(limit),
            "autocorrect": "1",
        }
    )
    url = "https://ws.audioscrobbler.com/2.0/?" + params
    try:
        payload = http_json(url)
    except Exception:
        cache_set(cache_key, [])
        return []
    similar = (((payload or {}).get("similarartists") or {}).get("artist")) or []
    if isinstance(similar, dict):
        similar = [similar]
    out = []
    for row in similar:
        name = str((row or {}).get("name") or "").strip()
        if not name:
            continue
        try:
            match = float((row or {}).get("match") or 0)
        except (TypeError, ValueError):
            match = 0.0
        out.append({"name": name, "match": match})
    cache_set(cache_key, out)
    return out


def soundcloud_search_track(artist: str) -> dict | None:
    client_id = soundcloud_client_id()
    if not client_id or not artist:
        return None
    cache_key = "sc:" + artist.lower()
    cached = cache_get(cache_key)
    if cached is not None:
        return cached  # type: ignore[return-value]
    params = urllib.parse.urlencode(
        {
            "q": artist,
            "client_id": client_id,
            "limit": "12",
            "app_locale": "en",
        }
    )
    url = "https://api-v2.soundcloud.com/search/tracks?" + params
    try:
        payload = http_json(url)
    except Exception:
        cache_set(cache_key, None)
        return None
    collection = (payload or {}).get("collection") or []
    artist_l = artist.lower()
    best = None
    for row in collection:
        if not isinstance(row, dict):
            continue
        if row.get("policy") == "BLOCK":
            continue
        user = row.get("user") or {}
        user_name = str(user.get("username") or user.get("full_name") or "").strip()
        title = str(row.get("title") or "").strip()
        permalink = str(row.get("permalink_url") or "").strip()
        if not permalink or not title:
            continue
        streamable = bool(row.get("streamable", True))
        if not streamable:
            continue
        artwork = str(row.get("artwork_url") or user.get("avatar_url") or "").strip()
        candidate = {
            "artist": user_name or artist,
            "title": title,
            "url": permalink.split("?")[0],
            "artwork": artwork.replace("-large.", "-t500x500.") if artwork else "",
            "source": "soundcloud",
        }
        hay = (user_name + " " + title).lower()
        if artist_l in hay or artist_l in user_name.lower():
            best = candidate
            break
        if best is None:
            best = candidate
    cache_set(cache_key, best)
    return best


def build_suggestions(seeds: list[dict], exclude_artists: list[str], limit: int = 5) -> list[dict]:
    exclude = {str(name or "").strip().lower() for name in exclude_artists if str(name or "").strip()}
    for seed in seeds:
        name = str((seed or {}).get("name") or "").strip()
        if name:
            exclude.add(name.lower())

    ranked: dict[str, dict] = {}
    ordered_seeds = sorted(
        seeds,
        key=lambda row: float((row or {}).get("score") or 0),
        reverse=True,
    )
    for seed in ordered_seeds[:8]:
        seed_name = str((seed or {}).get("name") or "").strip()
        seed_score = float((seed or {}).get("score") or 0)
        if not seed_name:
            continue
        for sim in lastfm_similar(seed_name):
            name = sim["name"]
            key = name.lower()
            if key in exclude:
                continue
            score = seed_score * (0.5 + float(sim.get("match") or 0))
            prev = ranked.get(key)
            if not prev or score > prev["score"]:
                ranked[key] = {"name": name, "score": score, "because": seed_name}

    candidates = sorted(ranked.values(), key=lambda row: row["score"], reverse=True)
    suggestions: list[dict] = []
    used_artists: set[str] = set()
    for cand in candidates:
        if len(suggestions) >= limit:
            break
        key = cand["name"].lower()
        if key in used_artists:
            continue
        track = soundcloud_search_track(cand["name"])
        if not track:
            continue
        track_artist = str(track.get("artist") or cand["name"]).strip()
        track_key = track_artist.lower()
        if track_key in exclude or track_key in used_artists:
            # Still allow if Last.fm name differs but prefer unique artists.
            if track_key != key and track_key in used_artists:
                continue
        used_artists.add(key)
        used_artists.add(track_key)
        suggestions.append(
            {
                "artist": track_artist or cand["name"],
                "title": track["title"],
                "url": track["url"],
                "artwork": track.get("artwork") or "",
                "source": "soundcloud",
                "because": cand.get("because") or "",
            }
        )
    return suggestions


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        print("[suggest-api]", fmt % args)

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.split("?", 1)[0] in ("/health", "/"):
            self._send(
                200,
                {
                    "ok": True,
                    "lastfm": bool(lastfm_key()),
                    "soundcloud": bool(soundcloud_client_id()),
                },
            )
            return
        self._send(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path not in ("/suggest", "/api/suggest-artists", "/"):
            self._send(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid json"})
            return
        if not lastfm_key():
            self._send(503, {"error": "LASTFM_API_KEY missing", "suggestions": []})
            return
        if not soundcloud_client_id():
            self._send(503, {"error": "SOUNDCLOUD_CLIENT_ID missing", "suggestions": []})
            return
        seeds = data.get("seeds") if isinstance(data.get("seeds"), list) else []
        exclude = data.get("excludeArtists") if isinstance(data.get("excludeArtists"), list) else []
        try:
            suggestions = build_suggestions(seeds, exclude, limit=5)
        except Exception as exc:
            self._send(500, {"error": str(exc), "suggestions": []})
            return
        self._send(200, {"suggestions": suggestions})


def main() -> None:
    load_env_file()
    ThreadingHTTPServer.allow_reuse_address = True
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    sc_env = bool((os.environ.get("SOUNDCLOUD_CLIENT_ID") or "").strip())
    print(f"[suggest-api] listening on http://{HOST}:{PORT}", flush=True)
    print(
        f"[suggest-api] lastfm={'yes' if lastfm_key() else 'NO'} "
        f"soundcloud_env={'yes' if sc_env else 'will-discover'}",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
