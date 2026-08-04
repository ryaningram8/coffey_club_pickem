# Nginx (reverse proxy)

## What it is

Nginx is the single entry point for all external traffic in production. It does two unrelated jobs at once here: serves the compiled Flutter **web** app as static files, and forwards API traffic to the backend container. Neither Postgres, Redis, nor the API container is ever exposed directly to the internet — Nginx is the only thing with ports `80`/`443` open to the outside world.

## How it works

Config: [nginx/nginx.conf](../../nginx/nginx.conf). Two `server` blocks:

1. **Port 80** — every request gets a `301` redirect to the `https://` version. Nginx never serves plaintext HTTP content, only the redirect.
2. **Port 443** — the real server:
   - Terminates TLS using a Let's Encrypt certificate (`ssl_certificate`/`ssl_certificate_key`, mounted read-only from `/etc/letsencrypt` on the host — see [14-deployment-proxmox.md](14-deployment-proxmox.md)).
   - `location /api/` → proxies to `http://api:4000/` (the `api` container, by its Compose service name — see [07-docker-compose.md](07-docker-compose.md)). Forwards real client IP and protocol headers (`X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) so the backend can log/reason about the original request even though it's arriving from Nginx's IP.
   - `location /` → serves static files from `/usr/share/nginx/html`, which is the Flutter web build output (`apps/web/build/web/`) mounted in read-only. `try_files $uri $uri/ /index.html` is the standard single-page-app fallback: if a path doesn't match a real file (e.g. someone deep-links to `/week/abc123`), Nginx serves `index.html` anyway and lets Flutter's router (GoRouter) figure out what to render client-side.
   - Static assets (`js`/`css`/images/fonts) get `Cache-Control: public, immutable` with a 1-year expiry — safe because Flutter's build process fingerprints filenames on every build, so a cached stale file is never served under the same name as a new one. `index.html` itself is explicitly `no-cache`, since that's the one file that must always be fetched fresh to pick up a new build.

## Where it runs

The `nginx` service in [docker-compose.yml](../../docker-compose.yml) — official `nginx:alpine` image (no custom Dockerfile needed, just the mounted config + static files). In production this is the container with ports `80`/`443` published to the host, and the Proxmox host's firewall/pfSense forwards external `443` traffic to it.

Not currently running on this dev machine — and it has a real prerequisite that isn't met yet: `apps/web/build/web/` doesn't exist (nobody's run `flutter build web` yet), so even if you started this container today it would 404 on `/`.

## How to view it

- Once running: `https://coffeyclub.example.com` in prod (replace with the real domain — `server_name` in `nginx.conf` is currently a placeholder and needs to be swapped for the real one).
- Locally, if you bring up the full Compose stack: `http://localhost` — but note `nginx.conf` as written hard-requires TLS certs to even start (the `443 ssl` block references `/etc/letsencrypt/live/coffeyclub.example.com/...`, which won't exist locally). To test Nginx itself locally you'd need to either get real certs via a tool like `mkcert`, or temporarily strip the `ssl_certificate` lines for a plain-HTTP local test block — not done yet.
- Config syntax check without starting anything: `docker run --rm -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t`.
- Logs once running: `docker compose logs -f nginx` (access + error logs, Nginx's defaults).

## Status in this project

Config file exists and looks structurally correct (proxy headers, SPA fallback, cache headers, TLS block) but has never actually been run in this project — it needs a real domain name in `server_name`, real Let's Encrypt certs, and a Flutter web build to serve before it can be verified end-to-end.
