# Google OAuth ("Sign in with Google")

## What it is

An alternative to email/password login — a user clicks "Sign in with Google," authenticates with their existing Google account, and this app trusts Google's confirmation instead of asking them to create and remember a separate password. OAuth (specifically OpenID Connect on top of it) is the standard protocol this flow runs on; you don't hand-roll it, you use Google's own SDKs on both ends.

## How it works

**Client side**: the `google_sign_in` Flutter package (declared in `packages/coffey_ui/pubspec.yaml`) drives the actual sign-in UI — a native Google account picker on mobile, a Google-hosted popup/redirect on web. On success, it hands the app an ID token proving who the user authenticated as.

**Server side**: that ID token gets POSTed to `POST /auth/google`. The backend uses the `google-auth-library` package to verify the token is genuinely signed by Google and hasn't been tampered with, extracts the user's email/name/Google account ID, and either finds an existing `User` with that `googleId` or creates one — then issues this app's own access/refresh tokens exactly like a normal login (see [06-auth-jwt.md](06-auth-jwt.md)). From that point on, Google is out of the picture entirely — the app's own JWTs are what govern every subsequent request.

In the `User` model, `passwordHash` is nullable specifically to accommodate this: a Google-only account has no password of its own.

Two credentials tie this together: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env` — these identify *this app* to Google, not any individual user.

## Where it runs

Google's own OAuth infrastructure handles the actual authentication UI and token issuance. Your only footprint is the client ID/secret and a small amount of registration (below).

## How to view/set it up

1. **Google Cloud Console** ([console.cloud.google.com](https://console.cloud.google.com)) → create a project (or reuse one) → APIs & Services → Credentials → Create OAuth client ID. You'll register:
   - A **Web** client ID (for the web app)
   - Possibly a separate **Android**/**iOS** client ID (Google's mobile SDKs sometimes need platform-specific ones, depending on how `google_sign_in` is configured)
2. You'll also configure an **OAuth consent screen** — the app name/logo/support email users see on the Google sign-in prompt itself. For a 50-person private invite-only app, this can stay in "Testing" mode (limited to explicitly added test users) rather than going through Google's full verification review, which is only needed for public-facing apps.
3. Paste the resulting client ID/secret into `.env` as `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`.
4. **To view/debug**: Google Cloud Console's Credentials page shows your registered client IDs and their configured redirect URIs/origins — if sign-in fails with a redirect-URI-mismatch style error, that's the first place to check. There's no separate "dashboard" beyond that; once working, the flow itself is just the standard Google account picker your users already know from every other app.

## Status in this project

A dedicated Web application OAuth client has been created (in the same GCP project as the `rji-home` Firebase project, kept separate from the pre-existing Home Assistant client) and `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are set in `.env`. Authorized JavaScript origins are configured for local dev (`http://localhost:8765`) and the dev VM (`https://coffeyclub-dev.saloosa.dev`) — no redirect URIs are needed, since `google_sign_in` v6's web implementation is a client-side popup flow (Google Identity Services), not a server-redirect flow.

The client ID reaches the Flutter web build via `--dart-define=GOOGLE_CLIENT_ID=...`, wired into `.claude/launch.json` for local dev; a production/dev-VM `flutter build web` needs the same flag passed manually (see [14-deployment-proxmox.md](14-deployment-proxmox.md)).

`AuthRepository`'s `GoogleSignIn` also sets `serverClientId` (in addition to `clientId`) to the same Web client ID, so Android/iOS ID tokens carry the right audience for backend verification — `clientId` alone only takes effect on web.

Not yet verified end-to-end with a real Google account sign-in — worth clicking through the actual flow once a backend + web build are running.
