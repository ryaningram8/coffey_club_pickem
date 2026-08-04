# Background jobs (BullMQ)

## What it is

[BullMQ](https://docs.bullmq.io) is a job queue library for Node.js, backed by Redis. It handles two things this app needs: work that should run **on a schedule** (repeating cron-style) and work that should run **later, once, in response to an event** (e.g. "email this user 3 hours before their pick deadline"). Rather than a `setInterval` in the app or a system cron job, jobs get pushed onto a Redis-backed queue and a worker process pulls them off — this gives retries, scheduling, and persistence for free.

## How it works

Three named queues, defined in [backend/src/lib/queues.ts](../../backend/src/lib/queues.ts): `odds-refresh`, `score-sync`, `notifications`. Workers for all three are started by `registerJobs()` in [backend/src/jobs/register.ts](../../backend/src/jobs/register.ts), called once from `server.ts` at boot — **there is no separate worker process**, the same Node process serving HTTP requests also runs these workers.

| Queue | Job class | Schedule | What it does |
|---|---|---|---|
| `odds-refresh` | `OddsRefreshJob` | repeat, cron `0 8 * * 1-5` (8am Mon–Fri) | Pulls spreads/O-U from The Odds API, matches to existing games |
| `score-sync` | `ScoreSyncJob` | repeat, cron `*/5 * * * 6,0` (every 5 min Sat & Sun) | Pulls live scores from ESPN, updates `Game` rows, scores `Pick`s when a game goes final |
| `notifications` | `PickReminderJob` | one-off, enqueued per-user when a commissioner publishes a week (from `assignGames` in `game.service.ts`) — fires `hoursBeforeDeadline` before that user's configured reminder time | Sends a push/email pick reminder |
| `notifications` | `ResultsNotificationJob` | one-off, enqueued per participant from `WeekCompleteJob` after a week finalizes | Sends a push/email results notification |

`WeekCompleteJob` ([backend/src/jobs/week-complete.job.ts](../../backend/src/jobs/week-complete.job.ts)) is a bit different from the others — it isn't on a queue itself, it's logic triggered by `score-sync` when it notices every game in a week is `final` or `cancelled`. It computes rankings/payouts (`WeeklyResult` rows) and then enqueues `ResultsNotificationJob` for everyone.

All job classes follow the same shape: a class with a `process()` method, called from inside a `Worker` callback in `register.ts`. Per CLAUDE.md, jobs are written to be **idempotent** — safe to run twice without double-counting or double-sending — since BullMQ will retry a job that throws.

## Where it runs

Inside the `api` container/process — same host, same port, no separate deployment unit. If you scale the API to multiple replicas later, you'd need to make sure only one replica runs the repeatable-job scheduling (BullMQ has patterns for this — not a concern yet at this scale).

## How to view it

There's no dashboard yet (see the Redis doc's note on Bull Board). Today, visibility is:

- **Server logs** — every job logs start/completion/errors via `pino` (per CLAUDE.md's job logging rule). `docker compose logs -f api` in prod, your terminal in dev.
- **Redis directly** — `KEYS bull:score-sync:*` etc. via `redis-cli`, to see queue depth and repeatable-job registrations.
- **Trigger one manually** to watch it run — since jobs are just classes with a `process()` method, you can `import` and call one directly from a scratch script or `tsx` REPL without waiting for its cron window, which is how `ScoreSyncJob`'s core logic was verified this project (see `spec.md`'s Phase 3 notes).

## Status in this project

`odds-refresh` and `score-sync` register and schedule without error at startup but haven't fired on their real cron window yet (it's currently off-season — no live games to sync). `score-sync`'s underlying logic (`syncGame`) has been exercised directly against a real completed ESPN game, though. `PickReminderJob`/`ResultsNotificationJob` are wired up (enqueued at the right trigger points) but haven't fired live — no published week with a near deadline, no completed week, in this pass.
