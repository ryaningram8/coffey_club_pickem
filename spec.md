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
- [ ] Run initial migration (`npm run db:migrate` after Docker is running)
- [x] Seed script: admin user, sample season/week

### Authentication (Backend)
- [ ] `POST /auth/signup` — validates invite code, creates user, returns tokens
- [ ] `POST /auth/login` — email + password, returns tokens
- [ ] `POST /auth/google` — Google OAuth token exchange
- [ ] `POST /auth/refresh` — refresh access token
- [ ] JWT middleware (auth guard for protected routes)
- [ ] Role-based access middleware (`requireRole`)

### Authentication (Flutter)
- [ ] Auth BLoC (login, signup, logout, token refresh)
- [ ] Login screen (email/password + Google Sign-In button)
- [ ] Signup screen (invite code entry → account creation)
- [ ] Secure token storage (flutter_secure_storage)
- [ ] Dio interceptor for auth headers + auto token refresh

---

## Phase 2 — Core Pick Flow

### Sports Data Services (Backend)
- [ ] ESPN API client (schedules, live scores, team data)
- [ ] The Odds API client (spreads, over/under)
- [ ] `OddsRefreshJob` — BullMQ job, runs Mon–Fri daily
- [ ] Team seed script (populate teams table from ESPN)

### Season & Week Management (Backend)
- [ ] `GET /seasons/:id` — season details
- [ ] `GET /seasons/:id/weeks` — list all weeks
- [ ] `POST /seasons` — create season (admin)
- [ ] `POST /seasons/:id/weeks` — create week (commissioner)
- [ ] `PUT /weeks/:id` — update week (label, deadline, status)
- [ ] `GET /weeks/current` — active week for current user

### Commissioner — Game Selection (Backend)
- [ ] `GET /games/available` — fetch upcoming Sat/Sun games from ESPN + odds
- [ ] `POST /weeks/:id/games` — assign selected 20 games to week
- [ ] `PUT /games/:id` — update game (replace postponed, edit spread/O/U)
- [ ] `DELETE /games/:id` — remove game from week (before deadline)

### Commissioner Dashboard (Flutter)
- [ ] Commissioner home screen (week list, status badges)
- [ ] Game browser screen (searchable list of available games with spread/O/U)
- [ ] Game selection flow (14 college + 6 NFL, count indicator)
- [ ] Week publish confirmation

### Pick Sheet (Backend)
- [ ] `GET /weeks/:id` — week details with all 20 games
- [ ] `GET /weeks/:id/picks` — get authenticated user's picks for week
- [ ] `POST /weeks/:id/picks` — submit/update picks (validates deadline)

### Pick Sheet (Flutter)
- [ ] Pick sheet screen (20 game cards in scrollable list)
- [ ] Game card widget (teams, game time, spread, O/U display)
- [ ] Team selection UI (tap to pick, highlight selected)
- [ ] Pick count progress indicator (e.g. "14 / 20 picks made")
- [ ] Submit button (disabled until all 20 picked)
- [ ] Picks BLoC (load, select, submit, deadline check)
- [ ] Deep link: `/week/:id` navigates to pick sheet

---

## Phase 3 — Results & Standings

### Score Sync (Backend)
- [ ] `ScoreSyncJob` — BullMQ cron, every 5 min Sat/Sun
- [ ] Update game scores + status from ESPN API
- [ ] On game `final`: set `winner_team_id`, score all picks for that game
- [ ] `WeekCompleteJob` — triggers when all games in week are final
- [ ] Calculate and write `weekly_results` (rank, payout amounts, tie splits)

### Results API (Backend)
- [ ] `GET /weeks/:id/standings` — weekly results with rankings
- [ ] `GET /seasons/:id/standings` — season leaderboard
- [ ] `GET /weeks/:id/picks/summary` — full pick breakdown (all users, for results view)

### Live Results (Flutter)
- [ ] Live results screen (polling or SSE for score updates)
- [ ] Game card with live score overlay
- [ ] Pick correctness indicators (green ✓ / red ✗ / gray in-progress)
- [ ] Live running score for the current user
- [ ] Live mini-leaderboard (top 5 players by current correct picks)

### Standings (Flutter)
- [ ] Weekly standings screen (rank list, payout column, tie indicators)
- [ ] Pick breakdown expandable (tap player to see their picks)
- [ ] Season standings screen (all-time leaderboard)
- [ ] Payout status per player (paid / unpaid badge)

### Payout Management (Backend + Flutter)
- [ ] `POST /admin/payouts/:weekId/mark` — mark individual payouts as sent
- [ ] Payout tracking view in commissioner dashboard (Venmo handle + paid toggle)

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
