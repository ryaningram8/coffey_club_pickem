# Authentication (JWT)

## What it is

Stateless, token-based auth. The server never stores "sessions" — instead, on login it hands the client two signed tokens, and every subsequent request proves who the user is by presenting one of those tokens. No cookies, no server-side session store.

## How it works

Two tokens, two purposes ([backend/src/lib/tokens.ts](../backend/src/lib/tokens.ts)):

- **Access token** — signed with `JWT_SECRET`, expires in **15 minutes**, payload is `{ sub: userId, role }`. This is what gets sent on every API call, as `Authorization: Bearer <token>`.
- **Refresh token** — signed with a *different* secret (`JWT_REFRESH_SECRET`), expires in **30 days**, payload is `{ sub: userId, type: 'refresh' }`. Used only to mint a new access token via `POST /auth/refresh` once the access token expires.

Using two different secrets means a leaked access token can't be used to forge a refresh token and vice versa — they're not interchangeable even though both are JWTs.

**Login/signup flow**: `POST /auth/login` (email+password, bcrypt-verified, cost factor 12 per CLAUDE.md) or `POST /auth/signup` (validates an invite code, marks it used, creates the `User`) or `POST /auth/google` (exchanges a Google ID token for a session) — all three return `{ accessToken, refreshToken }`.

**Per-request auth**: [backend/src/lib/middleware.ts](../backend/src/lib/middleware.ts) exports `authenticate` — a Fastify `preHandler` that reads the `Authorization` header, verifies the access token, and attaches `request.user = { id, role }`. Any route that needs a logged-in user adds this as a `preHandler`. `requireRole('commissioner', 'admin')` wraps `authenticate` and additionally 403s anyone whose role isn't in the allowed list — this is what protects commissioner/admin-only routes (game selection, payouts, broadcasts) per CLAUDE.md's rule that all such routes go through `requireRole`.

**Refresh**: when a client's access token expires (or is about to), it calls `POST /auth/refresh` with the refresh token; the server verifies it's a valid, non-expired `type: 'refresh'` token and issues a new access token. This is invisible to the user — no re-login every 15 minutes.

**On the Flutter side**: a Dio interceptor (in `coffey_ui`) attaches the access token to every outgoing request automatically and, on a 401, transparently calls `/auth/refresh` and retries — see [01-flutter-apps.md](01-flutter-apps.md).

## Where it runs

Entirely inside the backend API process — token signing/verification is pure computation, no external service involved (unlike Google OAuth, which does call out to Google — see [13-google-oauth.md](13-google-oauth.md)).

## How to view/verify it

- Log in via `curl -X POST http://localhost:4000/auth/login -d '{"email":"...","password":"..."}' -H "Content-Type: application/json"` and inspect the returned tokens.
- Decode a token's payload (without verifying the signature) at [jwt.io](https://jwt.io) — useful for confirming what's actually inside one during debugging. Never paste a *production* token into a third-party site; use a local decode (`node -e "console.log(JSON.parse(Buffer.from('<payload-segment>','base64url')))"`) if that matters to you.
- Hit a protected route without a token (`curl http://localhost:4000/users/me/notifications`) and confirm you get a 401 — this was verified live this session.
- `JWT_SECRET`/`JWT_REFRESH_SECRET` are just long random strings in `.env` — there's no external identity provider involved in generating or validating them.

## Status in this project

Fully implemented and exercised: signup, login, refresh, and role-gated routes are all live and were spot-checked this session (invalid login → 401, missing auth header → 401). The rejected/expired-refresh-token path specifically hasn't been individually exercised per `spec.md`.
