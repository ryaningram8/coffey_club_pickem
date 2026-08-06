# Coffey Club Pickem — CLAUDE.md

Architecture reference and coding rules for Claude Code. Read this before making any changes.

---

## Project Overview

Private invite-only football pick'em app for a group of 50+ friends. Players pick straight-up winners for 20 weekly games (14 college, 6 NFL). Points are tracked across the season with weekly payouts to top 3 finishers. Commissioners manage game selection; scores sync automatically from ESPN.

---

## Repository Structure

```
coffey_club_pickem/        ← git root
├── apps/
│   ├── web/          # Flutter web entrypoint (main.dart, web-specific config)
│   └── mobile/       # Flutter mobile entrypoint (main.dart, android/, ios/)
├── packages/
│   └── coffey_ui/    # Shared Flutter package — ALL shared code lives here
│       └── lib/
│           ├── blocs/        # BLoC/Cubit state management classes
│           ├── models/       # Dart data models (JSON serializable)
│           ├── repositories/ # API call layer (Dio + Retrofit)
│           ├── screens/      # Full page screens
│           ├── widgets/      # Reusable UI components
│           └── theme/        # Material 3 theme, colors, typography
├── backend/
│   └── src/
│       ├── routes/    # Fastify route handlers (thin — delegate to services)
│       ├── services/  # Business logic (thick — all domain logic here)
│       ├── jobs/      # BullMQ workers
│       ├── prisma/    # schema.prisma + migrations
│       └── lib/       # Shared utilities, API clients, middleware
├── docker-compose.yml
├── spec.md           # Feature checklist (update as work completes)
└── CLAUDE.md         # This file
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Material 3), targeting mobile + web |
| State Management | flutter_bloc (BLoC + Cubit pattern) |
| HTTP Client | Dio + Retrofit (codegen) |
| Navigation | GoRouter |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Backend | Node.js + TypeScript + Fastify |
| ORM | Prisma |
| Database | PostgreSQL 16 |
| Job Queue | BullMQ + Redis |
| Auth | JWT (access 15min + refresh 30d) |
| Hosting | Docker Compose on Proxmox homelab |
| Reverse Proxy | Nginx + Let's Encrypt |
| Sports Scores | ESPN unofficial API (free) |
| Sports Odds | The Odds API (paid, ~$20/mo) |

---

## Flutter / Dart Rules

### General
- All shared code goes in `packages/coffey_ui`. Never put business logic in `apps/web` or `apps/mobile` — those are entrypoints only.
- Use `freezed` for immutable model classes and union types (BLoC states/events).
- Use `json_serializable` for JSON models. Never write `fromJson`/`toJson` by hand.
- Prefer named constructors and factory methods on models.
- Never use `dynamic` or raw `Map<String, dynamic>` outside of generated code.

### BLoC Pattern
- Use **BLoC** (not Cubit) for complex state with multiple events (pick sheet, auth, live results).
- Use **Cubit** for simple toggle/UI state (notification prefs toggle, theme).
- One BLoC per feature domain. Never share a single BLoC across unrelated screens.
- Events are named in past tense: `PicksLoaded`, `PickSubmitted`, `AuthLoggedIn`.
- States use `freezed` unions: `initial`, `loading`, `success(data)`, `failure(message)`.
- BLoC classes live in `packages/coffey_ui/lib/blocs/<feature>/`.
- File structure per BLoC: `<feature>_bloc.dart`, `<feature>_event.dart`, `<feature>_state.dart`.

### Repositories
- One repository per domain: `AuthRepository`, `PicksRepository`, `WeekRepository`, etc.
- Repositories use Dio/Retrofit clients. They never contain business logic — just API calls and response mapping.
- Repository methods return typed model objects or throw typed exceptions (`ApiException`).
- Never call Dio directly from a BLoC. Always go through a repository.

### Navigation (GoRouter)
- All routes defined in a single `AppRouter` class in `packages/coffey_ui/lib/`.
- Use named routes. Never use string literals for route paths inline.
- Deep links are handled via GoRouter's `redirect` for auth guards.

### UI / Widgets
- Always use Material 3 components. Never use deprecated Material 2 widgets.
- Custom widgets go in `packages/coffey_ui/lib/widgets/`. Never inline complex widgets in screen files.
- Screen files should be thin — mostly `BlocBuilder`/`BlocListener` with widget composition.
- Use `SliverList` / `SliverGrid` for any scrollable list of 10+ items.

---

## Backend / TypeScript Rules

### General
- All route handlers in `src/routes/` are thin. They validate input, call a service, return the result.
- All business logic lives in `src/services/`. Services are the only place that touches Prisma.
- Never write raw SQL. Use Prisma query API exclusively.
- Always use TypeScript `strict` mode. No `any` types.
- Use `zod` for request body / query param validation in route handlers.

### Fastify Routes
- Group routes by domain in separate files: `auth.routes.ts`, `picks.routes.ts`, etc.
- Use Fastify's built-in schema validation (JSON Schema) for request/response typing.
- Return consistent error shapes: `{ error: string, code: string }`.
- HTTP status codes: 200 OK, 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict.

### Services
- Service methods are `async` and return typed objects.
- Services throw typed custom errors (`AppError` subclasses) that route handlers catch and translate to HTTP responses.
- Keep services focused — one service per domain (`AuthService`, `PicksService`, `StandingsService`).

### Prisma
- Schema file: `backend/src/prisma/schema.prisma`.
- Always run `prisma migrate dev` for schema changes during development.
- Never use `prisma.$queryRaw` unless absolutely necessary.
- Use `select` or `include` explicitly — avoid over-fetching with unbounded includes.

### BullMQ Jobs
- Job files in `src/jobs/`. Each job is a class with a `process()` method.
- Jobs should be idempotent — safe to retry on failure.
- Use named queues: `score-sync`, `notifications`, `odds-refresh`.
- Log job start, completion, and any errors via the logger.

### Auth / Security
- JWT access tokens expire in 15 minutes. Refresh tokens expire in 30 days.
- Passwords hashed with bcrypt (cost factor 12).
- Invite codes are validated at signup and marked used immediately (one-time use).
- All commissioner/admin routes are protected by `requireRole` middleware.
- Never expose password hashes or internal IDs in API responses.

---

## Database Conventions

- All primary keys are `uuid` (not serial int).
- All tables have `created_at` timestamp (auto-set).
- Soft deletes are not used — hard delete with cascade where needed.
- Enum values use snake_case strings matching TypeScript enums.
- Foreign key column names: `<table_singular>_id` (e.g. `week_id`, `user_id`).

---

## Environment Variables

Backend `.env`:
```
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET=...
JWT_REFRESH_SECRET=...
THE_ODDS_API_KEY=...
FIREBASE_SERVICE_ACCOUNT_JSON=...
RESEND_API_KEY=...         # or SMTP_HOST/USER/PASS for Nodemailer
APP_URL=https://coffeyclub.example.com
```

---

## Docker / Deployment

- `docker compose up` starts: postgres, redis, api, nginx.
- Flutter web build output (`apps/web/build/web/`) is mounted into the nginx container as static files.
- API is accessible at `/api/*` via Nginx proxy_pass.
- Mobile app points to `APP_URL` for all API calls.
- SSL certificates managed by certbot; pfSense forwards 443 to the Nginx container.

---

## Development Workflow

Three environments, each with a different purpose — don't skip straight to the last one:

1. **Local** (this dev machine) — fast iteration, no containers for `api`/Flutter. Run `docker compose up postgres redis` for just the database/queue backend, then `npm run dev` (backend) and `flutter run` (Flutter) directly. This is where most day-to-day development happens.
2. **Dev VM** (Proxmox, `https://coffeyclub-dev.saloosa.dev`) — the full containerized stack (`postgres`, `redis`, `api`, `nginx`), real TLS, near-production shape. "Works locally" does not mean "works containerized" — a Prisma/Alpine OpenSSL mismatch and a missing `curl` in the production image both only surfaced here, never locally.
3. **Production** — not yet provisioned. Until it exists, `main` and "what's deployed on the dev VM" are the same thing.

Process for a new feature:
- Branch off `main`: `feature/<name>`.
- Develop and test locally (environment 1) — this is the fast loop, use it for most changes.
- Before merging, deploy the branch to the dev VM (environment 2) if the change touches anything deployment-shaped: a new Prisma migration, `Dockerfile`/`docker-compose.yml`/`nginx` config, environment variables, or anything you just want to see running for real. Pure UI/logic changes can often skip straight to merge if locally verified.
- Merge to `main`, then redeploy: `git pull` + `docker compose up --build -d` (+ `prisma migrate deploy` if the migration hasn't been applied there yet) on whichever box is the deploy target — today that's always the dev VM; once production exists, deploying to dev and deploying to prod become separate, deliberate actions that don't have to happen together.

Once production holds real user data (not disposable seed data), migrations need more care than they do today: take a backup first, and prefer backward-compatible migrations (additive changes, avoid destructive column drops/renames in the same migration as code that depends on the old shape) so a mid-rollout state doesn't break. See the Postgres backup item in `TODO.md` — that needs to exist before this matters for real.

---

## Feature Tracking

See `spec.md` for the full feature checklist. Mark items `[x]` as they are completed.
Do not mark a spec item complete unless:
- Backend route (if applicable) is implemented and tested
- Flutter screen/widget (if applicable) is implemented
- The feature works end-to-end in docker compose
