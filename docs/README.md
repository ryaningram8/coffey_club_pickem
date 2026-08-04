# Coffey Club Pickem — technical docs

One file per moving piece of the stack. Each covers: what it is, how it works in this repo, where it runs, and how to actually go look at it.

Read them in this order if you're new to the stack — later ones assume earlier ones:

| # | Doc | Covers |
|---|-----|--------|
| 01 | [flutter-apps.md](01-flutter-apps.md) | Flutter web/mobile apps, `packages/coffey_ui`, BLoC, GoRouter, Dio |
| 02 | [backend-api.md](02-backend-api.md) | Fastify + TypeScript API server |
| 03 | [database-postgres.md](03-database-postgres.md) | Postgres + Prisma schema/migrations |
| 04 | [redis.md](04-redis.md) | Redis as the BullMQ broker |
| 05 | [bullmq-jobs.md](05-bullmq-jobs.md) | Background jobs — score sync, odds refresh, notifications |
| 06 | [auth-jwt.md](06-auth-jwt.md) | JWT access/refresh tokens, role guards |
| 07 | [docker-compose.md](07-docker-compose.md) | How the 4 containers fit together |
| 08 | [nginx.md](08-nginx.md) | Reverse proxy, static hosting, TLS termination |
| 09 | [espn-api.md](09-espn-api.md) | ESPN unofficial API — schedules & live scores |
| 10 | [odds-api.md](10-odds-api.md) | The Odds API — spreads & over/unders |
| 11 | [firebase-fcm.md](11-firebase-fcm.md) | Push notifications |
| 12 | [email-resend.md](12-email-resend.md) | Transactional email |
| 13 | [google-oauth.md](13-google-oauth.md) | "Sign in with Google" |
| 14 | [deployment-proxmox.md](14-deployment-proxmox.md) | The actual production host |

For the bird's-eye view of how these connect, see the architecture diagram from earlier in this conversation — this folder is the zoomed-in version of each box in that picture.

Every doc reflects the code as it exists on the `main` branch right now, not aspirational design — where something is stubbed, fails soft, or isn't wired up yet, the doc says so explicitly.
