# Production deployment (Proxmox homelab)

## What it is

Where the app actually lives once it's not just running on your dev machine. Per CLAUDE.md: a [Proxmox](https://www.proxmox.com) homelab server — self-hosted virtualization software you run on your own hardware, as opposed to a cloud provider like AWS/DigitalOcean. Docker Compose (the same stack described in [07-docker-compose.md](07-docker-compose.md)) runs inside a VM or LXC container on that Proxmox host. This is a genuinely different machine from the one this conversation has been running on — nothing about your current dev environment (the M450 SSD, the `nvm`/Flutter PATH setup) is relevant there; that machine needs its own Docker install.

## How it works

The full request path in production:

```
Internet → pfSense (port forward 443) → Nginx container (TLS termination)
    → static files (Flutter web build)  [for page loads]
    → api container, port 4000          [for /api/* calls]
        → postgres, redis containers
```

[pfSense](https://www.pfsense.org) is the router/firewall software forwarding external port 443 to the Proxmox VM's Nginx container — this is the layer that makes the app reachable from the public internet at all, distinct from anything in this repo. Certificates are issued and renewed by [certbot](https://certbot.eff.org) running on the host (not in a container per the current compose file — `/etc/letsencrypt` is mounted **read-only** into the `nginx` container from the host filesystem), so Nginx just consumes certs certbot already wrote to disk; it doesn't request them itself.

Deploying a change means, on that host: pulling the latest code, `flutter build web` (producing the static files Nginx mounts), and `docker compose up --build -d` to rebuild/restart the `api` and `nginx` containers with the new code. There's no CI/CD pipeline described anywhere in this repo yet — this would currently be a manual SSH-in-and-run-commands deploy.

## Where it runs

Physically: whatever hardware the Proxmox homelab is on, at whatever location that is (a machine in a closet, typically, for a homelab setup — not a datacenter). Logically: one VM/container running Docker, running the same 4-service Compose stack you'd run locally, just with production env values (real domain in `nginx.conf`'s `server_name`, real secrets in `.env`, `NODE_ENV=production`).

## How to view/access it

- **The app itself**: `https://coffeyclub.example.com` (a placeholder — swap for whatever real domain this ends up using, both in DNS and in [nginx.conf](../../nginx/nginx.conf)'s `server_name`).
- **The server**: SSH into the Proxmox VM/container directly — this repo doesn't define any web-based admin panel for the deployment itself, only for Proxmox's own management (Proxmox has its own web UI, typically `https://<host>:8006`, for VM/container management — separate from anything this app does).
- **Container health once deployed**: same `docker compose ps` / `docker compose logs -f <service>` commands as local dev (see [07-docker-compose.md](07-docker-compose.md)), just run on that host instead.
- **Certs**: `certbot certificates` on the host to check expiry/renewal status; certbot typically sets up its own auto-renewal (a systemd timer or cron job), worth confirming that's actually in place rather than assuming it.

## Status in this project

This is the least-built-out piece of the whole system relative to everything else documented here — the Compose file, Dockerfile, and nginx.conf are all written and structurally sound, but none of them have been run together as a full stack yet (only `postgres`+`redis` have actually been started, and only on this dev machine, not the Proxmox host). There's currently no evidence in this repo of the Proxmox VM/container itself being provisioned, pfSense port-forwarding being configured, or certbot having issued a first certificate — those are almost certainly the next real steps once the app itself is feature-complete enough to deploy.
