Jori's Music
Kind	URL
Mac local
http://127.0.0.1:8090/
Phone layout
http://127.0.0.1:8090/?iphone=1
Tailscale (tailnet)
https://jacobs-macbook-air.tailaac76e.ts.net/

Wayne's Music
Kind	URL
Mac local
http://127.0.0.1:8091/
Phone layout
http://127.0.0.1:8091/?iphone=1
Tailscale (tailnet)
https://jacobs-macbook-air.tailaac76e.ts.net:8443/

Jacob's Music
Kind	URL
Mac local
http://127.0.0.1:8092/
Phone layout
http://127.0.0.1:8092/?iphone=1
Tailscale (tailnet)
https://jacobs-macbook-air.tailaac76e.ts.net:8444/
Guest Wi‑Fi HTTPS
https://192.168.40.12:8445/?guest=1

Dan's Music
Kind	URL
Mac local
http://127.0.0.1:8093/
Phone layout
http://127.0.0.1:8093/?iphone=1
Guest Wi‑Fi HTTPS
https://192.168.40.12:8450/?guest=1
Tailscale Funnel (public)
https://jacobs-macbook-air.tailaac76e.ts.net:10000/

Steff's Music
Kind	URL
Mac local
http://127.0.0.1:8094/
Phone layout
http://127.0.0.1:8094/?iphone=1
Guest Wi‑Fi HTTPS
https://192.168.40.12:8451/?guest=1
Tailscale Funnel (public)
https://jacobs-macbook-air.tailaac76e.ts.net:8443/
Start / expose

App	Local Caddy	Tailscale	Guest
Jori / Wayne
each repo caddy run --config Caddyfile
jorismusic/scripts/tailscale-serve.sh (both)
—
Jacob
caddy run --config Caddyfile
jacobsmusic/scripts/tailscale-serve.sh
jacobsmusic/scripts/guest-serve.sh
Dan + Steff
dansmusic/scripts/start-both-guests.sh
tailscale-funnel-dan.sh + stefsmusic/scripts/tailscale-funnel-stef.sh
same script (8450 / 8451)