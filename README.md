# Jacob's Music

Personal music PWA (same stack as Jori's / Wayne's): Caddy, Tailscale, on-device library.

## Local server

```bash
caddy run --config Caddyfile
```

Listens on `127.0.0.1:8092`.

## Tailscale

```bash
./scripts/tailscale-serve.sh
```

Site URL: `https://<your-machine>.<tailnet>.ts.net:8444/`

## Guest install (same Wi‑Fi, no Tailscale)

When someone is on your Wi‑Fi and should install once and download the library:

```bash
./scripts/guest-serve.sh
```

- Serves **HTTPS on LAN port `8445`** (`tls internal` — one certificate warning in Chrome).
- Keeps **`:8092` on localhost** for Tailscale `:8444`.
- Writes **`images/jacobsmusic-guest-qr.png`** and prints the URL (`https://<lan-ip>:8445/?guest=1`).

Stop with Ctrl+C, then run normal `caddy run --config Caddyfile` if you do not want LAN exposed.

macOS may ask to allow incoming connections for Caddy the first time.

## Catalog

After adding files under `music/`:

```bash
./scripts/make-catalog.sh
```

`music/` is not in git.