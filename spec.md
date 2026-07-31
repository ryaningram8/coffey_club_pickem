# Coffey Club Pickem — Feature Spec

Living checklist of all features. Update status as work progresses.
Status: `[ ]` todo · `[~]` in progress · `[x]` done

---

## Phase 1 — Foundation

### Project Scaffolding
- [x] Initialize Flutter monorepo (`apps/web`, `apps/mobile`, `packages/coffey_ui`)
- [x] Initialize Node.js + TypeScript backend with Fastify
- [x] Set up Prisma with PostgreSQL connection
- [x] Configure Docker Compose (postgres, redis, api, nginx)
- [x] Configure Nginx to serve Flutter web + proxy `/api`
- [x] Set up environment variable structure (`.env.example`)
- [x] Initialize git repository with `.gitignore`

### Database
- [x] Write Prisma schema for all core tables
- [x] Run initial migration (`npm run db:migrate` after Docker is running)
- [x] Seed script: admin user, sample season/week

### Authentication (Backend)
- [x] `POST /auth/signup` — validates invite code, creates user, returns tokens
- [x] `POST /auth/login` — email + password, returns tokens
- [x] `POST /auth/google` — Google OAuth token exchange
- [x] `POST /auth/refresh` — refresh access token
- [x] JWT middleware (auth guard for protected routes)
- [x] Role-based access middleware (`requireRole`)

### Authentication (Flutter)
- [x] Auth BLoC (login, signup, logout, token refresh)
- [x] Login screen (email/password + Google Sign-In button)
- [x] Signup screen (invite code entry → account creation)
- [x] Secure token storage (flutter_secure_storage on mobile; plain SharedPreferences on web — see `token_storage.dart`, web's "secure" crypto layer proved unreliable across dev sessions and offers no real benefit there anyway)
- [x] Dio interceptor for auth headers + auto token refresh

---

## Phase 2 — Core Pick Flow

Fully exercised end-to-end in a real browser against a real dockerized
Postgres/Redis and the live ESPN API: login → commissioner creates a week →
browses live games → publishes → player views the pick sheet → changes a
pick → submits. Items still marked `[~]` are implemented but have no UI
entry point yet or weren't individually exercised (e.g. `PUT`/`DELETE` on a
single game — no screen calls these yet).

### Sports Data Services (Backend)
- [x] ESPN API client (schedules, live scores, team data) — fetched 32 NFL + 200 college teams and live scoreboards from the real API
- [~] The Odds API client (spreads, over/under) — only the "no API key configured" fail-soft path was exercised; the live-fetch path needs a real key to test
- [~] `OddsRefreshJob` — BullMQ job, runs Mon–Fri daily — registers and schedules without error at startup; the actual odds-matching run hasn't fired (it's a Mon–Fri cron, not manually triggered)
- [x] Team seed script (populate teams table from ESPN) — no longer a hard dependency for publishing (see game-selection notes below) but still useful for pre-populating the table; run successfully against live ESPN data

### Season & Week Management (Backend)
- [~] `GET /seasons/:id` — season details (no UI calls this by bare id; only `/seasons/active` is used)
- [x] `GET /seasons/:id/weeks` — list all weeks — powers the Commissioner Dashboard's week list
- [~] `POST /seasons` — create season (admin) — no UI screen for this yet, API-only
- [x] `POST /seasons/:id/weeks` — create week (commissioner)
- [~] `PUT /weeks/:id` — update week (label, deadline, status) — implemented, no UI entry point yet
- [x] `GET /weeks/current` — active week for current user — powers "This Week's Picks"
- [x] `GET /seasons/active` — active season for the commissioner dashboard (not in the original spec — added because nothing else let the commissioner UI discover which season to manage)

### Commissioner — Game Selection (Backend)
- [x] `GET /games/available` — fetch upcoming Sat/Sun games from ESPN + odds
- [x] `POST /weeks/:id/games` — assign selected games to week — upserts teams inline from the request rather than requiring pre-seeding, fixing a real bug where games against non-FBS opponents (not covered by the FBS-only team seed) failed to publish
- [~] `PUT /games/:id` — update game (replace postponed, edit spread/O/U) — implemented, no UI entry point yet
- [~] `DELETE /games/:id` — remove game from week (before deadline) — implemented, no UI entry point yet

### Commissioner Dashboard (Flutter)
- [x] Commissioner home screen (week list, status badges)
- [x] Game browser screen (searchable list of available games with spread/O/U)
- [x] Game selection flow (14 college + 6 NFL, count indicator)
- [x] Week publish confirmation

### Pick Sheet (Backend)
- [x] `GET /weeks/:id` — week details with all 20 games
- [x] `GET /weeks/:id/picks` — get authenticated user's picks for week
- [x] `POST /weeks/:id/picks` — submit/update picks (validates deadline — the future-deadline path is exercised; the rejected/expired-deadline path is not)

### Pick Sheet (Flutter)
- [x] Pick sheet screen (20 game cards in scrollable list)
- [x] Game card widget (teams, game time, spread, O/U display)
- [x] Team selection UI (tap to pick, highlight selected)
- [x] Pick count progress indicator (e.g. "14 / 20 picks made")
- [x] Submit button (disabled until all picked)
- [x] Picks BLoC (load, select, submit) — deadline-rejection path not individually exercised
- [x] Deep link: `/week/:id` navigates to pick sheet

---

## Phase 3 — Results & Standings

Backend fully exercised against real dockerized Postgres and real live ESPN
data (a real completed NFL game, fetched via `dates=` param) — verified game
sync, winner resolution, pick scoring, rank computation (incl. a real 2-way
tie), payout split, week completion, season standings rollup, and all new
HTTP routes end-to-end. Flutter screens were verified with `flutter test`
widget tests run against this same real backend (not mocked) — real HTTP
calls, real computed standings/ties/payouts, a real tap-to-expand pick
breakdown, and a real payout-toggle round trip — then the throwaway test
file and demo data script were exercised and the temporary test file
deleted per its own "not permanent" comment; `backend/src/__seed_demo.ts`
is left in place as reusable local demo-data seeding. Items marked `[~]`
work but weren't reachable in this pass (off-season — no live cron window
to observe naturally).

### Score Sync (Backend)
- [x] `ScoreSyncJob` — BullMQ cron, every 5 min Sat/Sun — worker registers and schedules without error at startup; the actual scheduled run hasn't fired (off-season, no games in flight) — its core logic (`syncGame`) was exercised directly against a real final ESPN game
- [x] Update game scores + status from ESPN API — `EspnGame` now carries live status/score, matched to DB games by `espnGameId`
- [x] On game `final`: set `winner_team_id`, score all picks for that game — ties (equal score) leave `winnerTeamId` null and score nobody correct
- [x] `WeekCompleteJob` — triggers when all games in week are final (or cancelled)
- [x] Calculate and write `weekly_results` (rank, payout amounts, tie splits) — added `Season.defaultWeeklyPot` + `Week.pot` (not in the original schema) so the payout pool is commissioner-configurable per week rather than hardcoded; ranking is standard competition ranking (1,2,2,4); tie-rank payouts use "place absorption" (tied players split the combined pct of the ranks they occupy) as a placeholder until tie-breaker picks exist

### Results API (Backend)
- [x] `GET /weeks/:id/standings` — weekly results with rankings
- [x] `GET /seasons/:id/standings` — season leaderboard
- [x] `GET /weeks/:id/picks/summary` — full pick breakdown (all users, for results view)

### Live Results (Flutter)
- [x] Live results screen (polling) — `LiveResultsBloc` polls every 15s; uses `GET /weeks/:id/picks/summary` rather than `/standings` for the live view, since `WeeklyResult` rows don't exist until the week fully completes but per-game `isCorrect` updates live as each game finalizes
- [x] Game card with live score overlay — `LiveGameCard`
- [x] Pick correctness indicators (green ✓ / red ✗ / gray in-progress) — `PickCorrectnessIcon`, shared with the standings pick breakdown
- [x] Live running score for the current user
- [x] Live mini-leaderboard (top 5 players by current correct picks)

### Standings (Flutter)
- [x] Weekly standings screen (rank list, payout column, tie indicators)
- [x] Pick breakdown expandable (tap player to see their picks)
- [x] Season standings screen (all-time leaderboard) — resolves the active season itself (route carries no seasonId), same pattern as `HomeScreen`'s current-week discovery
- [~] Payout status per player (paid / unpaid badge) — `isPaid` is fetched and available on `WeekStandingModel`; the player-facing weekly standings screen doesn't surface it (only the commissioner payouts screen does) since spec only asked for a payout *amount* column here, not paid status

### Payout Management (Backend + Flutter)
- [x] `POST /admin/payouts/:weekId/mark` — mark individual payouts as sent
- [x] Payout tracking view in commissioner dashboard (Venmo handle + paid toggle) — added `Season.defaultWeeklyPot`/`Week.pot` and `venmoHandle` to the standings DTO (not in the original spec) since payout amounts and Venmo handles had no source otherwise

---

## Phase 4 — Notifications & Polish

### Notifications (Backend)
- [ ] FCM integration (Firebase Admin SDK)
- [ ] Email integration (Resend API or Nodemailer + SMTP)
- [ ] `PickReminderJob` — scheduled when week published; fires at user-configured times
- [ ] `ResultsNotificationJob` — fires after `WeekCompleteJob`
- [ ] `POST /admin/broadcast` — commissioner sends manual push/email to all users
- [ ] `PUT /users/me/notifications` — update user notification preferences

### Notifications (Flutter)
- [ ] FCM token registration on login
- [ ] Notification preferences screen (toggles for each alert type + timing)
- [ ] In-app notification handling (route to correct screen on tap)

### Invitations (Backend + Flutter)
- [ ] `POST /invitations` — generate invite code (commissioner/admin)
- [ ] `GET /invitations` — list all invites + usage status
- [ ] Invite management screen (create, copy link, see who used it)

### User Management (Backend + Flutter)
- [ ] `GET /admin/users` — full user list with roles
- [ ] `PUT /admin/users/:id/role` — promote/demote user role
- [ ] Admin user management screen
- [ ] User profile screen (edit name, Venmo handle, notification prefs)

### Polish
- [ ] Empty states for all screens (no picks yet, off-season, etc.)
- [ ] Error handling and retry states in all BLoCs
- [ ] Loading skeletons for game cards and leaderboard rows
- [ ] Responsive layout breakpoints (mobile vs. wide web)
- [ ] Material 3 color scheme finalized
- [ ] App icon + splash screen (mobile)
- [ ] Web favicon + PWA manifest

---

## Phase 5 — Future Enhancements (Post-MVP)

- [ ] Side pools / weekly prop bets
- [ ] Confidence point scoring mode (pick weight 1–20)
- [ ] NFL playoffs extension
- [ ] Historical season archive (past seasons read-only)
- [ ] Commissioner analytics (most popular picks, upset rate per week)
- [ ] Pick lock override (commissioner can unlock for technical issues)
