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

## Catalog

After adding files under `music/`:

```bash
./scripts/make-catalog.sh
```

`music/` is not in git.