# TODO

Running list of things to come back to. Not a plan — just tracking so items don't get lost. Check items off as they're done.

## Security (self-hosting hardening)

- [ ] Remove the `ports:` publish for `postgres` and `redis` in [docker-compose.yml](docker-compose.yml) — currently exposed to the host/LAN, marked "local dev only" but not yet removed
- [ ] Add `@fastify/rate-limit` to `/login`, `/signup`, `/google` in [auth.routes.ts](backend/src/routes/auth.routes.ts) — no brute-force protection today
- [ ] Fix web refresh-token storage in [token_storage.dart](packages/coffey_ui/lib/src/services/token_storage.dart) — currently plain `localStorage` on web with a 30-day lifetime; move to httpOnly cookie or shorten lifetime for web clients
- [ ] Put the Docker host on its own VLAN in pfSense, WAN-forward only 443/80 — no network segmentation from other home devices yet
- [ ] Set up automated off-box Postgres backups (`postgres_data` volume has no backup strategy)
- [ ] Add basic security headers in [nginx.conf](nginx/nginx.conf) — HSTS, X-Content-Type-Options, X-Frame-Options
- [ ] Set up SOPS (age or PGP-encrypted `.env.enc`) for secrets management once there's a second environment (dev VM + prod) worth syncing via git — not needed yet for a single box with a hand-created local `.env`

## External services / infra setup

Real accounts/keys needed — code paths exist and fail soft, but nothing's been exercised against the real service yet.

- [ ] Firebase — no real Firebase project exists yet; create one, wire up `FIREBASE_SERVICE_ACCOUNT_JSON`, and get a real device token + real push delivered end-to-end (see [11-firebase-fcm.md](docs/11-firebase-fcm.md))
- [ ] The Odds API — no real key plugged in yet; get a key, set `THE_ODDS_API_KEY`, and confirm the response-mapping logic handles real spread data (see [10-odds-api.md](docs/10-odds-api.md))
- [ ] Resend (email) — no real account exists yet; create one, set `RESEND_API_KEY`, and confirm a real email actually sends (see [12-email-resend.md](docs/12-email-resend.md))
- [ ] Google OAuth — confirm a real `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` pair is in `.env` (Cloud Console project + OAuth consent screen still need setting up) and exercise sign-in with a real Google account (see [13-google-oauth.md](docs/13-google-oauth.md))
- [ ] Nginx — needs a real domain in `server_name`, real Let's Encrypt certs, and a Flutter web build to serve; never run end-to-end (see [08-nginx.md](docs/08-nginx.md))
- [ ] Docker Compose — `api` + `nginx` half of the stack has never been built/run as containers together, only `postgres`+`redis` (see [07-docker-compose.md](docs/07-docker-compose.md))
- [ ] Proxmox deployment — least-built-out piece overall: no Proxmox VM/container provisioned, no pfSense port-forwarding configured, no certbot cert issued yet (see [14-deployment-proxmox.md](docs/14-deployment-proxmox.md))
- [ ] Give the dev VM a real subdomain (e.g. `coffeyclub-dev.example.com`) with a real Let's Encrypt cert — needs hostname-aware routing (SNI/Host header) in front too, since pfSense port-forwarding alone can't route two hostnames on the same public IP:443 to different backend VMs

## Clean up

- [ ] Once the dev VM has a real subdomain + Let's Encrypt cert (see above), retire the no-TLS dev workaround: delete [nginx/nginx.dev.conf](nginx/nginx.dev.conf) and [docker-compose.override.yml](docker-compose.override.yml), replacing them with a real dev nginx config (same shape as [nginx.conf](nginx/nginx.conf), just pointed at the dev domain/cert paths)
