# Coffey Club Pickem — Feature Spec

Living checklist of all features. Update status as work progresses.
Status: `[ ]` todo · `[~]` in progress · `[x]` done

---

## Phase 1 — Foundation

**2026-08-04:** login (`POST /auth/login`) verified working through the actual full `docker compose` stack — all 4 services (`postgres`, `redis`, `api`, `nginx`) containerized and healthy together for the first time, on a Proxmox dev VM, Flutter web build served by `nginx` and proxied through to `api`. Everything below was previously tested with `postgres`/`redis` dockerized but `api` run locally via `npm run dev`, not the full containerized stack — that distinction is why this is called out separately rather than folded into the existing notes. Only login has been re-verified against the real stack so far; the rest of Phases 1–4 still reflect the earlier (non-fully-containerized) testing pass and should be revisited.

**2026-08-25:** the app is live in **production**, not just the dev VM — `https://coffeyclub.saloosa.dev`, real domain, real Let's Encrypt cert, real DMZ-isolated VM (`COFFEY_HOST`), reachable from the public internet. Loaded and interacted with from a phone on cellular data (not LAN): Flutter web app renders, and the round trip through nginx's `/api/` proxy to the `api` container to Postgres was exercised end-to-end. This was almost entirely infrastructure work (pfSense DMZ VLAN + firewall rules, DNS-01 cert issuance, Docker install, `.env` with fresh prod-only secrets) rather than app changes — see `TODO.md`'s Security and External services sections for the full writeup, including a couple of real gotchas hit along the way (pfSense's own admin GUI competing with the port-forward for port `443`; `docker-compose.override.yml` silently serving the dev nginx config on the first deploy attempt). One small app-level change did ship alongside this: the global error handler now ties a 500's log line to its `reqId` and returns that `reqId` in the response body, so a player-reported error can be traced to an exact backend log line instead of guessed by timestamp (also in `TODO.md`). Still open before this can be handed to real players: the admin user needs seeding on this box specifically, and off-box Postgres backups don't exist yet (both tracked in `TODO.md`).

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

Backend routes/services/jobs verified live against the real dockerized
Postgres/Redis (server boots clean, `tsc --strict` build passes): logged in
as the seeded admin and player, confirmed `GET`/`PUT /users/me/notifications`
persist across requests, `POST /users/me/fcm-token` stores a token,
`POST /admin/broadcast` reaches all 5 seeded users and correctly 403s a
non-commissioner, and the fail-soft path (no `FIREBASE_SERVICE_ACCOUNT_JSON`
/ `RESEND_API_KEY` configured) logs a warning and no-ops rather than
crashing — same pattern as `THE_ODDS_API_KEY` in Phase 2. Items marked `[~]`
are implemented and wired up but not reachable in this pass: no real
Firebase/Resend project is configured yet (so the actual push/email send
path is unexercised, only its fail-soft skip path is), and
`PickReminderJob`/`ResultsNotificationJob` are correctly scheduled by
`assignGames`/`WeekCompleteJob` but never fired live (no published week with
a near deadline, no completed week, in this pass — same class of gap as
Phase 3's cron jobs). Flutter: `flutter analyze` is clean across
`coffey_ui`/`mobile`/`web` and the app boots in a real browser against the
real backend with no console errors (Firebase inits without throwing even
with no project configured), but the notification-prefs screen itself
wasn't interactively exercised — this session's browser tool couldn't
render screenshots (confirmed environment-wide, not app-specific, by
failing identically on a plain static page), so it's marked `[~]` pending a
manual check.

### Notifications (Backend)
- [~] FCM integration (Firebase Admin SDK) — `lib/fcm-client.ts`; only the "not configured" fail-soft path was exercised live
- [~] Email integration (Resend API) — `lib/email-client.ts`; only the "not configured" fail-soft path was exercised live. Chose Resend over Nodemailer+SMTP to match the single-API-key pattern already used for Firebase/Odds
- [~] `PickReminderJob` — scheduled per-user (own `hoursBeforeDeadline` pref) when a week is published via `assignGames`; registers without error, hasn't fired live
- [~] `ResultsNotificationJob` — enqueued for every week participant from `WeekCompleteJob` after `finalizeWeek`; registers without error, hasn't fired live
- [x] `POST /admin/broadcast` — commissioner sends manual push/email to all users
- [x] `PUT /users/me/notifications` — update user notification preferences — added `GET /users/me/notifications` alongside it (not in the original spec) since the Flutter prefs screen needs to load current state before editing it

### Notifications (Flutter)
- [~] FCM token registration on login — `PushNotificationService` wired to `AuthBloc`'s authenticated stream; code path is analyzer-clean but unexercised against a real device token (no Firebase project configured)
- [~] Notification preferences screen (toggles for each alert type + timing) — `NotificationPrefsScreen` + `NotificationPrefsCubit`, reachable from Settings; not interactively verified in-browser this pass (see note above)
- [~] In-app notification handling (route to correct screen on tap) — `PushNotificationService._handleNotificationTap` routes `pick_reminder`/`results` payloads to the pick sheet / weekly standings; unexercised (no real push received)

### Invitations (Backend + Flutter)
- [~] `POST /invitations` — generate invite code(s) for a season (commissioner/admin); supports a targeted single email or an anonymous batch (`count`, up to 25) — verified locally end-to-end (signup consumes a code and joins the right season, reuse is rejected, non-admin is 403'd) but not yet run through the containerized dev-VM stack
- [~] `GET /invitations` — list invites + usage status, optionally filtered by `seasonId` — same verification status as above
- [x] Invite management screen (create, copy code/link, see who used it) — `InviteManagementScreen`, reachable via a mail icon in the admin-only Home header (moved off the Commissioner AppBar as part of the pool-scoped-roles rework, see `TODO.md`); lets a commissioner pick a pool from a dropdown (new `GET /seasons` list endpoint, since only "the active one" existed before), generate a single targeted-by-email or an anonymous batch (up to 25) of codes, and see each code's status (unused / reserved for an email / redeemed by whom / expired), with copy-code and (web-only) copy-signup-link actions. **2026-08-17: interactively verified in-browser locally**, closing the earlier gap where the environment's browser tool couldn't render screenshots or drive clicks.
- [x] `POST /invitations/:code/redeem` — not in the original spec; lets an *existing* logged-in user join an additional pool/season without creating a new account. Needed because a `SeasonMembership` join table (also not in the original spec) was added to make multiple concurrent pools possible — previously every `User` implicitly saw one single global "active season," with no notion of which pool they'd actually joined. `getActiveSeason`/`getCurrentWeek` now resolve per-user against `SeasonMembership` instead of globally, and `submitPicks` now 403s a pick submitted for a pool the user hasn't joined. Existing users were backfilled into whatever season(s) already existed so this didn't break anyone. Pool-switcher UI (`PoolSwitcherBar`, see `TODO.md`'s pool-scoped-roles Stage 3) now lets a user in multiple simultaneous pools choose directly rather than relying on the deterministic active-beats-upcoming fallback; interactively verified in-browser locally 2026-08-17.

### User Management (Backend + Flutter)
The original global-role design below (`PUT /admin/users/:id/role`) was superseded by the pool-scoped-roles rework (see `TODO.md`) — role is now per-pool (`SeasonMembership.role`), not a single flag on `User`. What actually shipped:
- [x] `GET /admin/users` — full user list with per-pool memberships/roles (not a single global role, per the rework above)
- [x] `PUT /admin/users/:id/memberships/:seasonId` / `DELETE .../memberships/:seasonId` — change or remove a user's role in a specific pool (replaces the originally-speced single `PUT .../role`)
- [x] Admin user management screen — `UserManagementScreen`, pool filter + per-row role toggle/remove; interactively verified in-browser locally 2026-08-17

### Polish
**2026-08-18:** `flutter analyze` is clean across `coffey_ui`/`mobile`/`web` and the
web app was booted against the real local backend (module bundle loads with
no fatal errors). Deeper interactive/visual verification (actually seeing
the skeletons shimmer, empty states render, retry buttons work) hit the
same browser-tool screenshot/semantics limitation noted earlier in this
phase — confirmed environment-wide again this session (`computer{screenshot}`
times out with "Browser pane is not displayed" on this page too), not
something introduced by this work. Everything below is marked `[~]` rather
than `[x]` for that reason, and because none of it has been run through the
containerized dev-VM stack yet — a manual check is still owed once the
browser tool (or a real device) is available.
- [~] Empty states for all screens (no picks yet, off-season, etc.) — new `EmptyStateView` widget; added to the pick sheet, live results, game browser (distinguishes "no games at all" from "no search results"), and season standings screens, which previously had no empty branch at all
- [~] Error handling and retry states in all BLoCs — new `ErrorStateView` widget wired into every BLoC/Cubit-backed screen's failure branch (previously every failure state rendered a dead-end message with no way to reload); `NotificationPrefsCubit` gained a public `reload()`; the home hero card's silently-blank failure case and the pool switcher's error case both now show a retry action too
- [~] Loading skeletons for game cards and leaderboard rows — new `ShimmerBox`/`SkeletonGameCard`/`SkeletonLeaderboardRow` widgets (hand-rolled animated gradient, no external shimmer package needed); used by the pick sheet, live results, weekly standings, and season standings screens in place of a bare spinner
- [~] Responsive layout breakpoints (mobile vs. wide web) — new `ResponsiveContent` widget caps list-style screen bodies to a centered max width above a 720px viewport breakpoint; applied to every screen that was previously a full-bleed single-column list (pick sheet, live results, both standings screens, payouts, user management, invite management, game browser, commissioner home/week, notification prefs, settings). Home/login/signup already had their own narrower width cap and were left as-is
- [x] Material 3 color scheme finalized — reviewed `app_theme.dart` and all screens/widgets: light/dark Cardinal+Gold schemes were already fully hand-tuned with explicit rationale comments, `ThemeCubit` persists the mode, and no hardcoded colors exist outside the theme file except one intentional semantic green (pick-correctness checkmark)
- [~] App icon + splash screen (mobile) — Android `ic_launcher` was still the wrong/stale crest artwork, not the real coffee-mug brand logo; regenerated all 5 legacy mipmap sizes plus a proper adaptive icon (`mipmap-anydpi-v26`, white background + mug foreground) from `coffey_club_logo.png`, and replaced the blank white splash (`launch_background.xml`) with the same logo centered on a white/dark-mode-aware background. No `ios/` project exists yet in `apps/mobile`, so this is Android-only for now
- [~] Web favicon + PWA manifest — favicon/icons were already correct (coffee-mug logo); fixed `manifest.json`'s `theme_color`/`background_color`, which were a leftover dark green (`#1B5E20`) that didn't match the actual Cardinal brand color, added a matching `<meta name="theme-color">` to `index.html`, and added maskable icon variants (`Icon-192/512-maskable.png`) for proper Android home-screen install masking

---

## Paper Pick Sheet (Commissioner Tool)

Commissioner-only fallback for players who can't use the app at all — see
[PAPER_PICK_SHEET_FEATURE.md](PAPER_PICK_SHEET_FEATURE.md) for the full design writeup.
Implemented on `feature/paper-pick-sheet` (commit `f50f97c`); code-reviewed against the
acceptance criteria but not yet exercised against a running `docker compose` stack, so
marked `[~]` per this file's own rule (don't mark `[x]` without an end-to-end docker
compose check) rather than `[x]`.

- [~] `GET /weeks/:id/pick-sheet.pdf` — commissioner-only PDF export of a published week
  (name/email header, kickoff time + network per game, blank line per team to write the
  pick) — `pdfkit`-based, no headless-browser dependency; guarded by the same
  `requirePoolCommissioner` primitive as other commissioner routes
- [~] `GET`/`PUT /weeks/:id/players/:userId/picks` — commissioner reads/enters a specific
  player's picks; skips the pick-deadline check on purpose (paper picks are written
  before the deadline even if typed in late), upserts on `[userId, gameId]` so
  re-entering/correcting doesn't duplicate or error
- [~] Season roster endpoint (name/email/role per member) — backs the "Enter Picks for
  Player" player picker
- [~] "Download Pick Sheet" action on the commissioner week screen — web + mobile save
  handling (`pick_sheet_download_web.dart`/`_io.dart`)
- [~] "Enter Picks for Player" screen — player picker + game list + submit, new
  `EnterPicksBloc` (multi-event state, per CLAUDE.md's BLoC-vs-Cubit rule)
- [~] Shell accounts for players with no `User` row at all — `isShellAccount` schema
  field (migration `20260901023359_add_user_is_shell_account`), "+ Create Player" option
  in the "Enter Picks for Player" dropdown, `POST /seasons/:id/members/shell`,
  signup-time merge-in-place (password and Google) when a shell's email matches a real
  signup — implemented and exercised against the local dev DB, not yet checked in a
  running `docker compose` stack (see the "Shell accounts" section of the feature doc)
- [ ] Upload-to-prefill (photo/scan of a filled sheet auto-fills picks for commissioner
  review) — idea only, not scoped, deferred

---

## Phase 5 — Future Enhancements (Post-MVP)

- [ ] Side pools / weekly prop bets
- [ ] Confidence point scoring mode (pick weight 1–20)
- [ ] NFL playoffs extension
- [ ] Historical season archive (past seasons read-only)
- [ ] Commissioner analytics (most popular picks, upset rate per week)
- [ ] Pick lock override (commissioner can unlock for technical issues)
