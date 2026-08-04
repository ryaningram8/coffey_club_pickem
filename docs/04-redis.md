# Redis

## What it is

An in-memory key-value store. In most stacks Redis wears two hats — cache and message broker — but in this codebase it currently only wears one: it's the **storage backend for BullMQ** (the job queue library — see [05-bullmq-jobs.md](05-bullmq-jobs.md)). There's no application-level caching layer built on top of it yet; nothing in `services/` reads or writes Redis directly.

## How it works

BullMQ needs somewhere durable-but-fast to keep queue state — which jobs are waiting, which are running, which repeat on a cron schedule, what data each job was given. Redis is what it uses for that. [backend/src/lib/redis.ts](../backend/src/lib/redis.ts) builds the connection options from `REDIS_URL` and hands them to BullMQ; [backend/src/lib/queues.ts](../backend/src/lib/queues.ts) then instantiates three named `Queue` objects (`odds-refresh`, `score-sync`, `notifications`) on top of that connection.

One implementation detail worth knowing: `redis.ts` deliberately passes a plain `{ host, port, password }` object to BullMQ rather than a real `ioredis` client instance — the comment in that file explains BullMQ bundles its own nested copy of `ioredis`, which TypeScript treats as a structurally different type from a standalone `ioredis` you'd `npm install` yourself. Passing options instead of an instance sidesteps the type mismatch entirely.

## Where it runs

The `redis` service in [docker-compose.yml](../docker-compose.yml): `redis:7-alpine`, password-protected (`--requirepass ${REDIS_PASSWORD}`), with a named volume (`redis_data`) so queue state survives a container restart. Currently running locally on this dev machine, port `6379` exposed to the host (same "local dev only, remove in prod" caveat as Postgres — production should only let the `api` container reach it over the internal Docker network).

## How to view it

1. **redis-cli inside the container** — `docker exec -it coffey_club_pickem-redis-1 redis-cli -a <REDIS_PASSWORD>`. From there:
   - `KEYS bull:*` — list all BullMQ-related keys (queue state, per-job hashes)
   - `MONITOR` — watch every command hit Redis in real time, useful for seeing a job get enqueued/processed live
2. **RedisInsight** (Redis's own free GUI) — point it at `localhost:6379` with the password from `.env`. Gives you a browsable tree of keys instead of raw CLI output.
3. There's no BullMQ dashboard (like [Bull Board](https://github.com/felixmosh/bull-board)) wired into this app yet — if you want a proper "here's every job, its status, its retry count" web UI instead of reading raw Redis keys or server logs, that's a small addition (an npm package + a few lines in `server.ts`) but hasn't been done.

## Status in this project

Confirmed this session: container is up and healthy. The API server connects to it successfully on boot (job workers register without error).
