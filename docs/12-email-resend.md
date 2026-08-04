# Email (Resend)

## What it is

[Resend](https://resend.com) is a transactional email API — the kind of service you use to send "your pick deadline is in 3 hours" or "week 7 results are in" emails from application code, as opposed to a personal inbox. CLAUDE.md's env var list originally sketched either Resend or SMTP/Nodemailer as options; Resend was the one actually built, chosen (per `spec.md`) to match the single-API-key pattern already used for Firebase and The Odds API rather than juggling SMTP host/port/user/pass.

## How it works

[backend/src/lib/email-client.ts](../backend/src/lib/email-client.ts) is a thin wrapper: `getClient()` lazily builds a `Resend` client from `RESEND_API_KEY`, caching `null` if it's unset so `sendEmail()` can silently no-op instead of crashing — the same fail-soft pattern used everywhere else in this codebase for optional third-party integrations. `sendEmail({ to, subject, html })` sends from `EMAIL_FROM` if set, otherwise falls back to Resend's shared sandbox sender (`onboarding@resend.dev`), which works without verifying your own domain — convenient for local/dev, not something you'd want in production (recipients would see a generic Resend address, not your own domain).

Called from `notification.service.ts`, triggered by the same two paths as push notifications: `PickReminderJob`/`ResultsNotificationJob` (automated, see [05-bullmq-jobs.md](05-bullmq-jobs.md)) and `POST /admin/broadcast` (manual, commissioner-triggered).

## Where it runs

Resend's own infrastructure — you never host anything. Your footprint is the API key in `.env` and, eventually, a verified sending domain if you want mail to come from your own address instead of the shared sandbox one.

## How to view it

1. **Get a key**: sign up at [resend.com](https://resend.com) — account creation, so that's on you, not something to script on your behalf. Free tier covers this scale easily.
2. **See sent mail**: Resend's dashboard has a full log of every email sent through your account — status (delivered/bounced/etc.), open/click tracking if enabled, and the rendered content of each send. This is the main way to "view" this system day to day.
3. **Exercise it through this app**: set `RESEND_API_KEY` in `.env`, restart the backend, then trigger `POST /admin/broadcast` or wait for a `PickReminderJob`/`ResultsNotificationJob` to fire — the email should show up both in the recipient's inbox and in Resend's dashboard log.
4. **Test the fail-soft path** (no signup needed): leave the key blank — you'll see a `RESEND_API_KEY not set — email notifications disabled` warning in the logs, and the rest of the app works fine without it.
5. **Verify your own domain** (needed before real production use, not required for testing): Resend dashboard → Domains → add DNS records at your registrar. Until this is done, `EMAIL_FROM` can't use your own domain — mail will come from the shared sandbox address.

## Status in this project

Confirmed live this session's predecessor pass (per `spec.md`): only the "not configured" fail-soft path has actually run — no real Resend account exists yet, so no real email has been sent. Same open item as Firebase: needs a real account + key before this is genuinely working end to end.
