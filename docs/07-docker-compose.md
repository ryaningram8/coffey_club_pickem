# Docker & Docker Compose

## What it is

Docker packages an app + its dependencies into a portable container image. Docker Compose is a tool for defining and running *multiple* containers together as one stack, described in a single YAML file, so you don't have to remember four separate `docker run` incantations with the right network/volume flags every time.

## How it works

[docker-compose.yml](../docker-compose.yml) at the repo root defines four services:

1. **`postgres`** — `postgres:16-alpine`, the database. See [03-database-postgres.md](03-database-postgres.md).
2. **`redis`** — `redis:7-alpine`, the job queue backend. See [04-redis.md](04-redis.md).
3. **`api`** — built from [backend/Dockerfile](../backend/Dockerfile) (this repo's own code, not a public image). Waits for `postgres` and `redis` to report `healthy` before starting (`depends_on: condition: service_healthy`), then runs the compiled Fastify server. See [02-backend-api.md](02-backend-api.md).
4. **`nginx`** — `nginx:alpine`, sits in front of everything. See [08-nginx.md](08-nginx.md).

All four sit on Compose's default private network, addressable by service name — this is why `nginx.conf` proxies to `http://api:4000` and the `api` service's `DATABASE_URL` points at host `postgres`, not `localhost`: inside that network, the service name *is* the hostname.

`depends_on: condition: service_healthy` means Compose won't even start `api` until Postgres and Redis pass their `healthcheck` (a `pg_isready`/`redis-cli ping` probe run every 10s). This avoids the classic "app crashes on boot because the database wasn't ready yet" race.

Two named volumes (`postgres_data`, `redis_data`) persist data outside the containers' own filesystem — you can `docker compose down` (which deletes containers) without losing data, but `docker compose down -v` would also delete the volumes and wipe the database.

## Where it runs

- **On this dev machine right now**: only `postgres` and `redis` are actually running via Compose (confirmed this session — `docker compose ps` shows both `Up ... healthy`). The `api` and `nginx` services are defined but not currently started; the backend has instead been run directly on the host via `npm run dev` for faster iteration (no rebuild-on-change needed).
- **In production**: all four services run together via Compose on the Proxmox homelab host. See [14-deployment-proxmox.md](14-deployment-proxmox.md).

## How to view/use it

- `docker compose ps` — what's running, and its health status.
- `docker compose up -d postgres redis` — start just the data layer (what's running now).
- `docker compose up --build` — build the `api` image from the current source and bring up the *entire* stack, including Nginx. This hasn't been done yet this session — worth trying once, to confirm the Dockerfile/nginx.conf actually work end-to-end rather than just existing on disk.
- `docker compose logs -f <service>` — tail logs for one service (`-f` follows).
- `docker compose down` — stop and remove containers (volumes survive).
- `docker compose config` — validate the YAML and print the fully-resolved config (env vars substituted in) without starting anything — useful for checking a `.env` value actually landed where you expect.

## Status in this project

`docker compose config` validates cleanly. Data layer (`postgres`+`redis`) has been running and healthy throughout this session. The `api`+`nginx` half of the stack is defined but hasn't been built/run as containers yet in this project — only tested by running the backend directly on the host.
