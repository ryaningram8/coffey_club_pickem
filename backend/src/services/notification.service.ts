import type { Prisma } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { NotFoundError } from '../lib/errors';
import { sendPushNotification } from '../lib/fcm-client';
import { sendEmail } from '../lib/email-client';
import { notificationsQueue } from '../lib/queues';
import { logger } from '../lib/logger';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface NotificationPrefs {
  pickReminders: {
    enabled: boolean;
    push: boolean;
    email: boolean;
    hoursBeforeDeadline: number;
  };
  resultsNotifications: {
    enabled: boolean;
    push: boolean;
    email: boolean;
  };
}

export type NotificationPrefsInput = Partial<{
  pickReminders: Partial<NotificationPrefs['pickReminders']>;
  resultsNotifications: Partial<NotificationPrefs['resultsNotifications']>;
}>;

const DEFAULT_PREFS: NotificationPrefs = {
  pickReminders: { enabled: true, push: true, email: false, hoursBeforeDeadline: 24 },
  resultsNotifications: { enabled: true, push: true, email: false },
};

// ─── Prefs ────────────────────────────────────────────────────────────────────

function parsePrefs(stored: Prisma.JsonValue): NotificationPrefs {
  const raw = (stored && typeof stored === 'object' ? stored : {}) as NotificationPrefsInput;
  return {
    pickReminders: { ...DEFAULT_PREFS.pickReminders, ...raw.pickReminders },
    resultsNotifications: { ...DEFAULT_PREFS.resultsNotifications, ...raw.resultsNotifications },
  };
}

export async function getNotificationPrefs(userId: string): Promise<NotificationPrefs> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { notificationPrefs: true } });
  if (!user) throw new NotFoundError('User');
  return parsePrefs(user.notificationPrefs);
}

export async function updateNotificationPrefs(
  userId: string,
  input: NotificationPrefsInput,
): Promise<NotificationPrefs> {
  const current = await getNotificationPrefs(userId);
  const updated: NotificationPrefs = {
    pickReminders: { ...current.pickReminders, ...input.pickReminders },
    resultsNotifications: { ...current.resultsNotifications, ...input.resultsNotifications },
  };
  await prisma.user.update({
    where: { id: userId },
    data: { notificationPrefs: updated as unknown as Prisma.InputJsonValue },
  });
  return updated;
}

// ─── FCM token registration ────────────────────────────────────────────────────

export async function registerFcmToken(userId: string, token: string): Promise<void> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { fcmTokens: true } });
  if (!user) throw new NotFoundError('User');
  if (user.fcmTokens.includes(token)) return;

  await prisma.user.update({
    where: { id: userId },
    data: { fcmTokens: { push: token } },
  });
}

async function pruneInvalidTokens(userId: string, invalidTokens: string[]): Promise<void> {
  if (invalidTokens.length === 0) return;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { fcmTokens: true } });
  if (!user) return;

  const kept = user.fcmTokens.filter((t) => !invalidTokens.includes(t));
  await prisma.user.update({ where: { id: userId }, data: { fcmTokens: { set: kept } } });
}

// ─── Pick reminders ───────────────────────────────────────────────────────────

/**
 * Sends a single user their pick reminder for a week, if their prefs still
 * allow it and they haven't already finished picking. Safe to call from a
 * delayed job whose target time has since become stale (week edited,
 * deadline passed, or picks already submitted) — those cases are silent
 * no-ops rather than errors, since a stale reminder isn't a failure.
 */
export async function sendPickReminder(userId: string, weekId: string): Promise<void> {
  const [user, week] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.week.findUnique({ where: { id: weekId }, include: { games: true } }),
  ]);
  if (!user || !week) return;
  if (week.status !== 'picks_open' || week.pickDeadline <= new Date()) return;

  const prefs = parsePrefs(user.notificationPrefs);
  if (!prefs.pickReminders.enabled) return;

  const pickCount = await prisma.pick.count({ where: { userId, weekId } });
  if (pickCount >= week.games.length) return;

  const remaining = week.games.length - pickCount;
  const title = `Pick reminder — ${week.label}`;
  const body = `You have ${remaining} of ${week.games.length} picks left before the deadline.`;

  if (prefs.pickReminders.push && user.fcmTokens.length > 0) {
    const result = await sendPushNotification(user.fcmTokens, {
      title,
      body,
      data: { type: 'pick_reminder', weekId },
    });
    await pruneInvalidTokens(userId, result.invalidTokens);
  }
  if (prefs.pickReminders.email) {
    await sendEmail({ to: user.email, subject: title, html: `<p>${body}</p>` });
  }

  logger.info({ userId, weekId, remaining }, 'Pick reminder sent');
}

// ─── Results notifications ─────────────────────────────────────────────────────

/**
 * Notifies a single week participant of their finalized results. No-ops if
 * they opted out or never picked that week (no WeeklyResult row).
 */
export async function sendResultsNotification(userId: string, weekId: string): Promise<void> {
  const [user, week, result] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.week.findUnique({ where: { id: weekId } }),
    prisma.weeklyResult.findUnique({ where: { userId_weekId: { userId, weekId } } }),
  ]);
  if (!user || !week || !result) return;

  const prefs = parsePrefs(user.notificationPrefs);
  if (!prefs.resultsNotifications.enabled) return;

  const title = `Results are in — ${week.label}`;
  const payoutLine = result.payoutAmount ? ` You earned $${result.payoutAmount.toString()}.` : '';
  const body = `You went ${result.correctPicks}/${result.totalPicks} correct, finishing #${result.rank}.${payoutLine}`;

  if (prefs.resultsNotifications.push && user.fcmTokens.length > 0) {
    const pushResult = await sendPushNotification(user.fcmTokens, {
      title,
      body,
      data: { type: 'results', weekId },
    });
    await pruneInvalidTokens(userId, pushResult.invalidTokens);
  }
  if (prefs.resultsNotifications.email) {
    await sendEmail({ to: user.email, subject: title, html: `<p>${body}</p>` });
  }

  logger.info({ userId, weekId, rank: result.rank }, 'Results notification sent');
}

/**
 * Schedules a delayed pick-reminder job per user, timed to each user's own
 * `hoursBeforeDeadline` preference. Called once when a week is first
 * published. jobId is deterministic per (week, user) so re-publishing
 * (e.g. adding more games before lock) is a safe no-op rather than a
 * duplicate reminder — BullMQ rejects an add() with a jobId already queued.
 * Scoped to `seasonId`'s members — otherwise publishing a week in one pool
 * would queue a reminder for every user in every pool.
 */
export async function schedulePickReminders(
  weekId: string,
  seasonId: string,
  pickDeadline: Date,
): Promise<void> {
  const users = await prisma.user.findMany({
    where: { seasonMemberships: { some: { seasonId } } },
    select: { id: true, notificationPrefs: true },
  });

  for (const user of users) {
    const prefs = parsePrefs(user.notificationPrefs);
    if (!prefs.pickReminders.enabled) continue;

    const fireAt = pickDeadline.getTime() - prefs.pickReminders.hoursBeforeDeadline * 60 * 60 * 1000;
    const delay = fireAt - Date.now();
    if (delay < 0) continue;

    try {
      await notificationsQueue.add(
        'pick-reminder',
        { userId: user.id, weekId },
        { delay, jobId: `pick-reminder-${weekId}-${user.id}` },
      );
    } catch (err) {
      logger.error({ err, userId: user.id, weekId }, 'Failed to schedule pick reminder');
    }
  }
}

/** Every user who submitted at least one pick in a week — the results-notification audience. */
export async function getWeekParticipantIds(weekId: string): Promise<string[]> {
  const picks = await prisma.pick.findMany({
    where: { weekId },
    select: { userId: true },
    distinct: ['userId'],
  });
  return picks.map((p) => p.userId);
}

/** Enqueues a results-notification job for every week participant. Called from WeekCompleteJob. */
export async function scheduleResultsNotifications(weekId: string): Promise<void> {
  const userIds = await getWeekParticipantIds(weekId);

  for (const userId of userIds) {
    try {
      await notificationsQueue.add(
        'results-notification',
        { userId, weekId },
        { jobId: `results-notification-${weekId}-${userId}` },
      );
    } catch (err) {
      logger.error({ err, userId, weekId }, 'Failed to schedule results notification');
    }
  }
}

// ─── Broadcast ──────────────────────────────────────────────────────────────────

export interface BroadcastInput {
  title: string;
  message: string;
  channels: Array<'push' | 'email'>;
  /** Omitted (admin only) = everyone; otherwise scoped to this pool's members. */
  seasonId?: string;
}

/**
 * Admin- or pool-commissioner-initiated announcement, independent of
 * per-category notification prefs — an explicit broadcast isn't gated by
 * the automated pick-reminder/results toggles. Scoped to `seasonId`'s
 * members when given, otherwise every user in the system (admin-only, per
 * the route's authorization check).
 */
export async function broadcast(input: BroadcastInput): Promise<{ recipientCount: number }> {
  const users = await prisma.user.findMany({
    where: input.seasonId
      ? { seasonMemberships: { some: { seasonId: input.seasonId } } }
      : undefined,
    select: { id: true, email: true, fcmTokens: true },
  });

  if (input.channels.includes('push')) {
    const allTokens = users.flatMap((u) => u.fcmTokens);
    if (allTokens.length > 0) {
      await sendPushNotification(allTokens, {
        title: input.title,
        body: input.message,
        data: { type: 'broadcast' },
      });
    }
  }

  if (input.channels.includes('email')) {
    await Promise.all(
      users.map((u) =>
        sendEmail({ to: u.email, subject: input.title, html: `<p>${input.message}</p>` }),
      ),
    );
  }

  return { recipientCount: users.length };
}
