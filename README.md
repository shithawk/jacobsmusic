# Jacob's Music

Personal music PWA (same stack as Jori's / Wayne's): Caddy, Tailscale, on-device library.

## Local server

```bash
caddy run --config Caddyfile
```

Listens on `127.0.0.1:8092`.

## Tailscale (Android PWA)

One-shot before installing or updating on a phone:

```bash
./scripts/prepare-pwa-install.sh
```

That rebuilds catalogs, starts Caddy on `:8092`, runs Tailscale Serve on `:8444`, and refreshes `images/jacobsmusic-tailscale-qr.png`.

Or only Tailscale:

```bash
./scripts/tailscale-serve.sh
```

Site URL: `https://<your-machine>.<tailnet>.ts.net:8443/` (or `:8444/`) — Chrome → **Install app** (or open once to pull a service-worker update).

## Guest install (same Wi‑Fi, no Tailscale)

When someone is on your Wi‑Fi and should install once and download the library:

```bash
./scripts/guest-serve.sh
```

- Writes **`caddy-data/Caddyfile.guest.runtime`** with your current LAN IP (`https://<ip>:8445` — required for TLS to work).
- Serves **HTTPS on LAN port `8445`** (`tls internal` — tap **Advanced → Proceed** on Android if Chrome says “not private”).
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