# ESPN API (sports data)

## What it is

ESPN publishes an unofficial, undocumented, free JSON API that its own website/apps use internally (`site.api.espn.com`). It's not a product you sign up for — no API key, no account, no rate-limit contract, no SLA. It's reverse-engineered and could change or disappear without notice, which is why the code treats every call as something that can fail and shouldn't take the app down with it.

This is where the app gets: the season's game schedule, team names/logos/conferences, and live scores.

## How it works

[backend/src/lib/espn-client.ts](../../backend/src/lib/espn-client.ts) wraps two endpoints:

- `getScoreboard(sport, { week?, date? })` — schedule + live status/score for a sport (`college` or `nfl`). College football is filtered to `groups=80` (FBS only) to keep the game list to relevant teams instead of every Division II/III school. Maps ESPN's status strings (`STATUS_POSTPONED`, `state: 'in'`, `completed: true`, etc.) onto this app's own `GameStatus` enum (`scheduled`/`in_progress`/`final`/`postponed`/`cancelled`).
- `getTeams(sport)` — full team list (name, abbreviation, logo URL, conference), used to seed the `Team` table.

`getScoreboardSafe` is the fail-soft wrapper actually used by callers that shouldn't crash if ESPN is down or changes shape — it catches, logs, and returns an empty array instead of throwing.

**Who calls it, and when**:
- The commissioner's game browser (`GET /games/available`) calls `getScoreboard` live to show upcoming games to pick from.
- `ScoreSyncJob` (a BullMQ job, every 5 min Sat/Sun during the season) calls it to refresh live scores and detect when games go final. See [05-bullmq-jobs.md](05-bullmq-jobs.md).
- A one-time seed script (`db:seed:teams`) calls `getTeams` to pre-populate the `Team` table, though per `spec.md` this is no longer a hard requirement — `assignGames` now upserts teams inline from whatever's in the request, which is what fixed a real bug where non-FBS opponents weren't in the pre-seeded team list.

## Where it runs

Nowhere you host — it's ESPN's own infrastructure (`site.api.espn.com`), called over plain HTTPS from wherever the backend happens to be running (your dev machine right now, the Proxmox box in prod). No env var, no key, no config — it's a hardcoded base URL.

## How to view it

- Poke the raw API directly in a browser or `curl`, e.g.: `curl "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"` — useful for seeing exactly what shape ESPN returns before touching the client code.
- Exercise it through this app: `GET /games/available` on the running backend, or watch `ScoreSyncJob`'s logs during a live game window.
- There's no dashboard or console — it's a free, anonymous public endpoint, not an account you log into.

## Status in this project

Exercised against the real live API this project: fetched 32 NFL teams + ~200 college teams, and live scoreboards. `ScoreSyncJob`'s core sync logic was verified directly against a real completed NFL game. The recurring cron job itself hasn't fired on its actual schedule yet (off-season, no games currently in flight to sync).
