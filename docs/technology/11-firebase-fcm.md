# Firebase Cloud Messaging (push notifications)

## What it is

Firebase is Google's mobile/web backend-as-a-service platform. This app uses exactly one piece of it: **Firebase Cloud Messaging (FCM)**, the push notification delivery system — the same underlying mechanism iOS/Android/web push notifications generally go through regardless of who wrote the app. See the earlier explanation in this conversation for what "a Firebase project" concretely is (the container resource in Google's console that this all hangs off of).

## How it works — two halves

**Server side** — [backend/src/lib/fcm-client.ts](../../backend/src/lib/fcm-client.ts): uses the `firebase-admin` SDK to send pushes to a list of device tokens. `getApp()` lazily initializes from `FIREBASE_SERVICE_ACCOUNT_JSON` (a full service-account key, pasted as a single-line JSON string in `.env`) — if that's unset or fails to parse, it caches `null` and every send silently no-ops rather than crashing. `sendPushNotification(tokens, payload)` sends to up to 500 tokens at once (FCM's multicast limit) and returns which tokens were rejected as invalid/unregistered, so the caller can prune stale tokens from a user's stored list.

**Client side** — in `packages/coffey_ui`: `PushNotificationService` (uses the `firebase_messaging` Flutter package) obtains a device-specific FCM token and registers it with the backend via `POST /users/me/fcm-token`, wired to fire whenever `AuthBloc`'s authenticated stream emits (i.e., right after login). It also handles `_handleNotificationTap`, routing a tapped notification's payload (`pick_reminder` / `results`) to the right screen (pick sheet / weekly standings).

Both `apps/web/lib/main.dart` and `apps/mobile/lib/main.dart` call `Firebase.initializeApp()` in a `try/catch` — if there's no Firebase config present for that build (no `firebase_options.dart`/`google-services.json`/`GoogleService-Info.plist`), it silently skips push setup and the rest of the app works normally.

**Who triggers a send**: `PickReminderJob` and `ResultsNotificationJob` (BullMQ jobs, see [05-bullmq-jobs.md](05-bullmq-jobs.md)) for automated notifications, and `POST /admin/broadcast` for a commissioner manually pushing a message to everyone.

## Where it runs

Google's infrastructure (FCM's delivery network) — you never host anything for this yourself. Your two footprints are: the service-account key on the backend, and the client config bundled into each Flutter build.

## How to view/set it up

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com) (free tier is enough at this scale).
2. Add a **Web app** and an **Android app** (and iOS, if you're building for it) inside that project — each gives you a client config snippet.
3. For Flutter specifically, the easiest path is the `flutterfire configure` CLI (from the `flutterfire_cli` package) — it logs into your Firebase account and generates `firebase_options.dart` plus drops the native config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) into the right spots automatically, rather than copy-pasting each by hand.
4. Project settings → **Service accounts** → Generate new private key → downloads a JSON file → paste its contents as one line into `FIREBASE_SERVICE_ACCOUNT_JSON` in the backend's `.env`.
5. To watch a real push happen: Firebase console → Cloud Messaging → you can also send a one-off test message from there directly to a registered device token, independent of this app's own code — useful for isolating "is Firebase set up right" from "is this app's code sending correctly."

## Status in this project

Backend: server boots clean, `POST /users/me/fcm-token` stores a token, but only the "not configured" fail-soft path has run live (no real Firebase project exists yet). Flutter: `flutter analyze` is clean and the app boots without throwing even with no Firebase project configured, but no real device token has ever been obtained or a real push actually delivered. This is the single biggest "next step beyond the Flutter code" item from this conversation.
