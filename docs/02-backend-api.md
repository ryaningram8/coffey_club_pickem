# Backend API (Fastify + TypeScript)

## What it is

The single server process that everything else talks to. It's a REST API written in TypeScript on [Fastify](https://fastify.dev) (a Node.js HTTP framework, similar role to Express but faster and with built-in schema validation). It's the *only* thing in the system allowed to talk to Postgres — Flutter never touches the database directly, it only calls this API.

## How it works

Entry point: [backend/src/server.ts](../backend/src/server.ts).

On boot it, in order:
1. Registers CORS — in dev, allows any `localhost:*` origin (Flutter's dev server picks a random port); in production, restricts to `APP_URL`.
2. Calls `registerRoutes(server)` — mounts every route file under a prefix. See [backend/src/routes/index.ts](../backend/src/routes/index.ts):

   | Prefix | File | Domain |
   |---|---|---|
   | `/auth` | `auth.routes.ts` | signup, login, Google OAuth, refresh |
   | `/seasons` | `season.routes.ts` | season CRUD, season standings |
   | `/weeks` | `week.routes.ts` | week CRUD |
   | `/games` | `game.routes.ts` | commissioner game selection |
   | `/weeks` | `pick.routes.ts` | pick sheet (shares the `/weeks` prefix) |
   | `/weeks`, `/seasons` | `standings.routes.ts` | results & standings |
   | `/admin` | `admin.routes.ts` | payouts, broadcast notifications |
   | `/users` | `user.routes.ts` | notification prefs, FCM token registration |

3. Calls `registerJobs()` — starts the BullMQ workers (see [05-bullmq-jobs.md](05-bullmq-jobs.md)). Background jobs run **inside this same process**, not a separate service.
4. Registers `GET /health` → `{ status: "ok" }`.
5. Registers a global error handler that turns thrown errors into consistent JSON: `AppError` subclasses map to their `statusCode`, `ZodError` (bad request body) maps to 400, anything else maps to 500.
6. Listens on `0.0.0.0:${PORT}` (default `4000`).

### Layering rule (enforced by convention, not code)

Routes are thin. A route handler validates the request (via `zod`), calls a service method, and shapes the HTTP response. All business logic — the actual rules of the game — lives in `src/services/*.ts`. Services are the only files that import `@prisma/client` and touch the database. This split matters because it's what CLAUDE.md's "never write business logic in a route handler" rule is enforcing — routes should be swappable (e.g. if you ever added GraphQL) without touching game logic.

Services in [backend/src/services/](../backend/src/services/): `auth.service.ts`, `game.service.ts`, `pick.service.ts`, `results.service.ts`, `season.service.ts`, `week.service.ts`, `notification.service.ts`.

## Where it runs

- **Local dev**: directly on your machine via `npm run dev` (`tsx watch src/server.ts`) — no container. Auto-restarts on file save. This is what's been running throughout this session.
- **Docker Compose**: the `api` service, built from [backend/Dockerfile](../backend/Dockerfile) (multi-stage: builds with full `node_modules`, ships only the compiled `dist/` + production deps in a `node:22-alpine` image). This container isn't currently running — only `postgres` and `redis` are up right now.
- **Production**: same `api` container, on the Proxmox homelab, sitting behind Nginx (see [08-nginx.md](08-nginx.md)).

Either way it listens on port `4000` inside its own network namespace/host. It's never exposed directly to the internet — Nginx is always in front of it.

## How to view/exercise it

- **Health check**: `curl http://localhost:4000/health`
- **Logs**: [backend/src/lib/logger.ts](../backend/src/lib/logger.ts) wraps `pino`. In dev, `pino-pretty` makes it human-readable in your terminal. In Docker, logs go to `docker compose logs -f api`.
- **Manually hit routes**: any HTTP client (`curl`, Postman, Insomnia) against `http://localhost:4000`. Protected routes need `Authorization: Bearer <access_token>` from `/auth/login`.
- **Type-check without running**: `npx tsc --noEmit -p backend` (needs Node 18+ — see the dev-environment note in project memory if `node --version` shows something old).
- **Build for production**: `npm run build` → emits `dist/`.

## Status in this project

Builds clean (`tsc --noEmit` passes), boots clean against the real dockerized Postgres/Redis, and responds correctly to real requests (verified this session: `/health` returns 200, invalid login returns 401, unauthenticated protected routes return 401). No automated test suite currently exists in the repo.
