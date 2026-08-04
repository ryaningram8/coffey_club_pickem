# The Odds API (spreads & over/unders)

## What it is

A paid, real third-party API ([the-odds-api.com](https://the-odds-api.com), ~$20/mo per CLAUDE.md) that aggregates betting lines from sportsbooks — point spreads and over/under totals. Unlike ESPN, this one is a real product: you sign up, get an API key, and are subject to a rate limit tied to your plan.

It's **cosmetic** in this app, not load-bearing — the pick'em is straight-up winner picks, spreads/O-U are just displayed on the game card for context (helping players gauge favorites). Nothing about scoring or pick validity depends on it.

## How it works

[backend/src/lib/odds-client.ts](../../backend/src/lib/odds-client.ts) exports `getOdds(sport)`. It checks `THE_ODDS_API_KEY` first — if unset, it logs a warning and returns an empty array immediately, no network call at all. If set, it calls `GET /v4/sports/{sport_key}/odds` with `regions=us&markets=spreads,totals&oddsFormat=american`, and maps the first bookmaker's spread/totals markets onto `{ homeTeamName, awayTeamName, commenceTime, spread, overUnder }`. Any request failure (bad key, rate limit, network error) is caught, logged, and also returns an empty array rather than throwing — same fail-soft pattern as the Firebase/Resend clients.

Consumed by `game.service.ts` when building the commissioner's "available games" list (spreads shown alongside ESPN's schedule data), and by `OddsRefreshJob` (a BullMQ job scheduled 8am Mon–Fri) which periodically refreshes odds for already-selected games. See [05-bullmq-jobs.md](05-bullmq-jobs.md).

## Where it runs

Nowhere you host — it's the-odds-api.com's infrastructure, called over HTTPS from the backend. Your only footprint is the API key in `.env`.

## How to view it

- **Get a key**: sign up at [the-odds-api.com](https://the-odds-api.com) — this is an account-creation step, so it's on you to do, not something to script/automate on your behalf.
- **Check your usage/quota**: the-odds-api.com's own dashboard, once you have an account — shows remaining requests against your plan.
- **Exercise it through this app**: once `THE_ODDS_API_KEY` is set in `.env` and the backend restarted, `GET /games/available` or the `OddsRefreshJob` logs will show real spread/O-U data instead of the "not configured" warning.
- **Test the fail-soft path** (no signup needed): leave the key blank — you'll see `THE_ODDS_API_KEY not set — skipping odds fetch` in the logs, and the app works fine without spreads showing.

## Status in this project

Only the "no API key configured" fail-soft path has actually been exercised — nobody has plugged in a real key yet, so the live-fetch path (actual spread data flowing through) is unverified. This is one of the "next steps beyond the Flutter code" items: getting a real key and confirming the mapping logic handles real API responses correctly.
