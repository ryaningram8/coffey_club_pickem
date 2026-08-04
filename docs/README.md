# Coffey Club Pickem — technical docs

One file per moving piece of the stack. Each covers: what it is, how it works in this repo, where it runs, and how to actually go look at it.

## Technology

Read them in this order if you're new to the stack — later ones assume earlier ones:

| # | Doc | Covers |
|---|-----|--------|
| 01 | [flutter-apps.md](technology/01-flutter-apps.md) | Flutter web/mobile apps, `packages/coffey_ui`, BLoC, GoRouter, Dio |
| 02 | [backend-api.md](technology/02-backend-api.md) | Fastify + TypeScript API server |
| 03 | [database-postgres.md](technology/03-database-postgres.md) | Postgres + Prisma schema/migrations |
| 04 | [redis.md](technology/04-redis.md) | Redis as the BullMQ broker |
| 05 | [bullmq-jobs.md](technology/05-bullmq-jobs.md) | Background jobs — score sync, odds refresh, notifications |
| 06 | [auth-jwt.md](technology/06-auth-jwt.md) | JWT access/refresh tokens, role guards |
| 07 | [docker-compose.md](technology/07-docker-compose.md) | How the 4 containers fit together |
| 08 | [nginx.md](technology/08-nginx.md) | Reverse proxy, static hosting, TLS termination |
| 09 | [espn-api.md](technology/09-espn-api.md) | ESPN unofficial API — schedules & live scores |
| 10 | [odds-api.md](technology/10-odds-api.md) | The Odds API — spreads & over/unders |
| 11 | [firebase-fcm.md](technology/11-firebase-fcm.md) | Push notifications |
| 12 | [email-resend.md](technology/12-email-resend.md) | Transactional email |
| 13 | [google-oauth.md](technology/13-google-oauth.md) | "Sign in with Google" |
| 14 | [deployment-proxmox.md](technology/14-deployment-proxmox.md) | The actual production host |

## Concepts

Background knowledge that isn't specific to this repo's code, but that decisions in this project depend on:

| # | Doc | Covers |
|---|-----|--------|
| 15 | [networking-basics.md](concepts/15-networking-basics.md) | VLANs, DNS, TLS/Let's Encrypt, port forwarding — the homelab networking concepts behind the open VLAN/domain decisions |

For the bird's-eye view of how these connect, see the architecture diagram from earlier in this conversation — the Technology folder is the zoomed-in version of each box in that picture.

Every doc reflects the code as it exists on the `main` branch right now, not aspirational design — where something is stubbed, fails soft, or isn't wired up yet, the doc says so explicitly.
