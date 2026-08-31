# Feature: Paper Pick Sheet for Offline Players

Status: **Not started — scoped, ready to plan/implement.**
Origin: conversation with Ryan, 2026-08-27. Bring this file back to Claude Code to resume.

## Problem

Some players have technical issues that prevent them from using the app at all (can't
install it, can't log in, etc.), so they can't submit picks through the normal in-app
flow. The commissioner needs a way to get them a paper pick sheet, then key their picks
into the system on their behalf.

This is a commissioner-only tool. Anyone who *can* use the app still submits picks
through the app as normal — this is strictly a fallback for people who can't.

## Reference: legacy sheet

`~/Downloads/2024 WEEK 13 SHEET - Google Sheets.pdf` (shared earlier in this
conversation) is the hand-run Google Sheets version of this the club has used in past
seasons. It shows the general shape worth mimicking: name/week header, two-column game
list with kickoff time + network + blank lines for the pick, one row per game. It also
contains a lot of extra material (last week's standings, payouts, "Pit of Misery") that
is explicitly **out of scope** — see Decisions below.

## Decisions made (don't re-litigate these)

- **PDF scope:** just the current week's games — name/week header, kickoff time,
  network (if available), a blank line per game to write the pick. No standings, no
  payouts, no "last week's winners," no tiebreaker section.
- **Tiebreaker:** explicitly out of scope. The app has no tiebreaker concept today
  ([schema.prisma](backend/src/prisma/schema.prisma) has nothing on `Week`/`Game` for
  it) and this feature should not add one. Ryan wants to reconsider tiebreakers as its
  own separate feature later — don't bundle it in here.
- **Re-entry method:** manual. The commissioner reads the filled-out paper sheet and
  types the picks into the app themselves, player by player, game by game. No
  OCR/scanning/auto-import of any kind — handwriting recognition was considered and
  explicitly rejected as not worth the complexity/unreliability.
- **PDF format:** a flat, printable sheet (print it, write on it by hand, sheet comes
  back some other way — photo, scan, in person). Not a fillable PDF form. No PDF
  form-field library needed.
- **Who can get one:** commissioner-only capability. There is no "this player is
  offline" flag on `User`/`SeasonMembership` — the commissioner can download a sheet
  for any published week, and can key in picks on behalf of any player. No schema
  changes needed for this (the PDF export and pick-entry routes themselves) — but see
  **Shell accounts for players with no account at all** below, which *does* need a
  schema change, for the case where the player has never signed up at all.
- **Deadline enforcement for commissioner-entered picks:** none. The commissioner can
  enter picks for a player at any time, before or after `Week.pickDeadline`. This is
  intentional — paper picks are physically written before the deadline even if they're
  typed into the app late. Still enforce structural correctness (one pick per game per
  player, picked team must be one of the game's two teams) — just skip the deadline
  check.

## Gaps confirmed against current code (as of 2026-08-27)

- No PDF generation library in [backend/package.json](backend/package.json) — nothing
  like `puppeteer`, `pdfkit`, `pdf-lib`. Need to add one.
- [pick.routes.ts](backend/src/routes/pick.routes.ts) only supports self-submission —
  `POST /:id/picks` always writes picks as `request.user.id`. There is no path for one
  user (commissioner) to submit picks for another user. Needs a new route.
- Commissioner-only route guard pattern already exists and should be reused:
  `requirePoolCommissioner` in [week.routes.ts](backend/src/routes/week.routes.ts:66)
  (see also line 83). Model the new routes' auth on this.
- `Pick` has a `@@unique([userId, gameId])` constraint
  ([schema.prisma:213](backend/src/prisma/schema.prisma)) — the commissioner-entry
  service should `upsert` on that, not just `create`, so re-entering/correcting a
  player's paper picks doesn't blow up on a duplicate.

## Proposed implementation shape (not yet built)

### Backend

1. **PDF export route** — commissioner-only, e.g.
   `GET /weeks/:id/pick-sheet.pdf`, guarded the same way as
   [week.routes.ts:66](backend/src/routes/week.routes.ts:66)
   (`requirePoolCommissioner`). Loads the week + its games (already have this query
   shape via `gamesInclude` in
   [week.service.ts](backend/src/services/week.service.ts)), renders a PDF, returns it
   with `Content-Type: application/pdf`.
   - **Library choice still open.** Given the layout is a simple repeating
     row/two-column table (not the full legacy sheet), a programmatic drawing library
     like `pdfkit` is probably a better fit than spinning up headless Chromium
     (`puppeteer`/`playwright`) just for this — smaller Docker image, no extra
     browser dependency to manage in the containerized deploy. Confirm this trade-off
     before implementing; revisit if the layout turns out to need more visual fidelity
     than `pdfkit`'s canvas-style API comfortably gives.
2. **Commissioner pick-entry route** — commissioner-only, e.g.
   `PUT /weeks/:id/players/:userId/picks` (or similar — pick a shape that doesn't
   collide with the existing `POST /:id/picks` self-submit route in
   [pick.routes.ts](backend/src/routes/pick.routes.ts)). Body: array of
   `{ gameId, pickedTeamId }`, same shape as the existing `submitPicksBody` schema.
   - New service function (in `pick.service.ts`) that mirrors `submitPicks` but:
     - takes an explicit `targetUserId` instead of using the caller's own id,
     - skips the `pickDeadline` check that the self-submit path presumably has,
     - upserts on `[userId, gameId]` so it's safe to call repeatedly for corrections,
     - validates `pickedTeamId` is one of the game's `homeTeamId`/`awayTeamId`.
   - Confirm the target user is actually a member of the week's season
     (`SeasonMembership`) before writing picks for them.

### Flutter

1. **Download button** on
   [commissioner_week_screen.dart](packages/coffey_ui/lib/src/screens/commissioner/commissioner_week_screen.dart)
   — add alongside the existing "Payouts" `IconButton` in the `AppBar.actions` (line
   ~38-47) or as a second FAB/menu item next to "Edit Games" (line ~49-56). Hits the
   new PDF route via a repository method
   (add to [week_repository.dart](packages/coffey_ui/lib/src/repositories/week_repository.dart),
   following the existing `guard(() => _api...)` pattern). Needs platform-specific
   handling for actually saving/opening the PDF (Flutter web: trigger a browser
   download; mobile: save to device / open share sheet) — check what plugins (if any)
   are already in `pubspec.yaml` for file handling before adding a new dependency.
2. **New screen**: "Enter Picks for Player" reachable from
   `commissioner_week_screen.dart` (e.g. another AppBar action or FAB menu item).
     - Player picker: needs a list of the season's members — check whether an existing
       repository call already exposes season membership/roster, or whether one needs
       to be added.
     - Game list + pick selection: likely reusable pieces from
       [pick_game_card.dart](packages/coffey_ui/lib/src/widgets/pick_game_card.dart),
       the same widget presumably used in the normal player pick-submission flow.
     - Submit action calls the new commissioner pick-entry repository method.
   - Decide whether this needs its own BLoC (per CLAUDE.md's rule: BLoC for complex
     multi-event state, Cubit for simple toggle state) or can follow the
     `commissioner_week_screen.dart` pattern of a plain `FutureBuilder`/`StatefulWidget`
     — that screen's own doc comment says it deliberately skips a BLoC for a "simple
     fetch-and-display" case; this screen has more state (player selection + per-game
     picks + submit) so a BLoC is more likely justified. Judge against CLAUDE.md's
     BLoC rules at implementation time.

## Shell accounts for players with no account at all

Status: **Not started — scoped, ready to plan/implement.**
Origin: conversation with Ryan, 2026-08-31.

### Problem

Everything above assumes the target player already has a `User` row (the doc's own
acceptance criteria said as much: "does not require the target player to have ever
logged into the app themselves *beyond having an account*"). But some players may
never have signed up at all — no `User` row exists, so there's no `userId` to write
`Pick` rows against and no `SeasonMembership` to satisfy the "confirm target user is a
member of the week's season" check. The commissioner still needs to key in that
person's paper picks from week 1, have them show up correctly in live results and
season standings, and then — when that person eventually creates a real account
(possibly weeks later) — have their real account pick up right where the shell left
off, with no duplicate user and no lost history.

### Decided design

- The commissioner gets a UI to create a **shell account**: a `User` row with just a
  name and email (entered by the commissioner, on the player's behalf), plus a
  `SeasonMembership` for the current season so the shell user shows up in live results
  and season standings like any other player. `passwordHash` and `googleId` stay null
  — this is already a representable state in the schema (it's the same nullability
  used for Google-only accounts today).
- The commissioner then uses the existing commissioner pick-entry route (above) against
  that shell user's `id`, exactly as if the player had a normal account. This works for
  as many weeks as needed with no special-casing in the pick-entry path itself.
- When the player later creates a real account (password signup or Google), the
  **same email** is used to look up a matching `User` row. If a match is found and
  `isShellAccount` is `true`, the signup flow *updates that existing row in place*
  (sets `passwordHash`/`googleId`, updates `name`, flips `isShellAccount` to `false`)
  instead of creating a new `User`. Because it's the same `id`, all `Pick` rows,
  `WeeklyResult` rows, and `SeasonStanding` rows the commissioner entered on their
  behalf stay attached automatically — no migration needed.

### Schema change required

This **does** require a schema change, which supersedes the "no schema changes needed"
line above (that line still holds for the base paper-pick-sheet feature — entering
picks for someone who already has an account — but not for this shell-account
extension):

- Add `isShellAccount Boolean @default(false)` to `User` in
  [schema.prisma](backend/src/prisma/schema.prisma:49).

### Gaps confirmed against current code (as of 2026-08-31)

- **Password signup currently hard-rejects any existing email** —
  [auth.service.ts:79-80](backend/src/services/auth.service.ts:79):
  ```ts
  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) throw new ConflictError('An account with this email already exists');
  ```
  This needs to branch on `isShellAccount`: if an existing row is found and
  `isShellAccount` is `true`, update it in place (set `passwordHash`, update `name`,
  flip `isShellAccount` to `false`) instead of throwing. Only throw `ConflictError`
  when the existing row is a real (non-shell) account. Also skip creating a
  `SeasonMembership` for a season the shell row is already a member of — the
  `@@unique([userId, seasonId])` constraint would otherwise throw on the redundant
  insert.
- **Google auth already does an email-based merge, but not shell-aware** —
  [auth.service.ts:150-155](backend/src/services/auth.service.ts:150) already links a
  Google sign-in to any existing `User` row matching that email (attaches `googleId`
  to it) regardless of shell status. It needs two additions: flip `isShellAccount` to
  `false` on that merge, and update `name` from the Google payload (today it only sets
  `googleId`, leaving whatever placeholder name the commissioner typed).
- **Shell login already fails cleanly with no extra work** —
  [auth.service.ts:113-114](backend/src/services/auth.service.ts:113) already requires
  `user?.passwordHash` to be truthy for password login, and a shell account's
  `passwordHash` is null, so a login attempt against an unclaimed shell account already
  returns the normal "Invalid email or password" error. No change needed here.

### Known limitation — accepted, not solved here

Matching is **exact-email-only**. If the commissioner enters the wrong email for the
shell account, or the player later signs up with a different email than the one on
file, there's no auto-link: the player ends up with a second, empty `User` row, and
the shell account (with its picks/history) is orphaned permanently. This design does
not attempt to solve that — no fuzzy matching, no "did you mean" prompt. A manual
commissioner "merge two user accounts" tool would close this gap but is explicitly
**out of scope** for now; revisit if it turns out to happen often in practice.

### Open items to nail down at implementation time

- UI for shell-account creation: where it lives in the commissioner flow (likely
  alongside or folded into the "Enter Picks for Player" screen from the base feature
  above — e.g. an "Add offline player" option in the player picker instead of a
  separate screen).
- Whether shell-account creation requires selecting a season up front (to create the
  `SeasonMembership`) or defaults to the season of the week the commissioner is
  currently working in.
- Whether an invite code is still validated/consumed when a shell account is claimed
  via signup, or whether matching an existing shell row bypasses that requirement
  entirely (the player is already a season member at that point via the shell's
  `SeasonMembership`).

## Open items to nail down at implementation time

- Exact PDF layout details: single column vs. two column like the legacy sheet, exact
  header text, font/sizing, page size (Letter vs A4).
- Final choice of PDF library (see note above).
- Exact route paths/method verbs for the two new backend endpoints (proposals above are
  placeholders, not final).
- Where the "Enter Picks for Player" entry point lives in the commissioner UI
  (AppBar action vs. FAB menu vs. new nav item) — current commissioner week screen only
  has one FAB ("Edit Games") and one AppBar action ("Payouts"), so adding two more
  entry points needs a UI decision (e.g. combine into an overflow menu).
- How the commissioner finds out who still needs a paper sheet / hasn't picked yet —
  check whether an existing "who has and hasn't submitted picks" view already exists
  before building a new one.

## Acceptance criteria (draft)

- [ ] Commissioner can download a PDF of a published week's games, showing kickoff
      time, network (if available), matchup, and a blank line to write the pick.
- [ ] Commissioner can select any player in the season and enter/edit their picks for
      the current week's games, at any time (before or after the pick deadline).
- [ ] Entering picks this way does not require the target player to have ever logged
      into the app themselves beyond having an account.
- [ ] Re-entering/correcting a player's picks via this flow overwrites their previous
      picks for that game rather than erroring or duplicating.
- [ ] This capability is not reachable by non-commissioner users.
- [ ] No changes to `schema.prisma` are required for the base paper-pick-sheet feature
      (entering picks for someone who already has an account) — confirm this still
      holds once implementation starts. (The shell-account extension below is the one
      exception and does require a schema change — see that section.)

### Shell accounts (extension)

- [ ] Commissioner can create a shell account (name + email, no password) for a player
      with no existing `User` row, enrolled in the current season via
      `SeasonMembership`.
- [ ] A shell account's picks, entered via the commissioner pick-entry route, appear
      correctly in live results and season standings like any other player's.
- [ ] When a player with a matching-email shell account signs up for real (password or
      Google), their existing shell `User` row is updated in place — not duplicated —
      and `isShellAccount` flips to `false`.
- [ ] All picks/results/standings entered against the shell account remain attached
      after the real account claims it (same `User.id` throughout).
- [ ] Signing up with an email that does not match any shell account behaves exactly
      as it does today (unaffected by this feature).
