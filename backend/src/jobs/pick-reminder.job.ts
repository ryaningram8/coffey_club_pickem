import { sendPickReminder } from '../services/notification.service';
import { logger } from '../lib/logger';

/**
 * Sends one user their pick reminder for one week. Scheduled as a delayed
 * BullMQ job (jobName 'pick-reminder' on the shared notifications queue)
 * when a week is published — see week.service.ts assignGames.
 */
export class PickReminderJob {
  async process(userId: string, weekId: string): Promise<void> {
    logger.info({ userId, weekId }, 'PickReminderJob starting');
    await sendPickReminder(userId, weekId);
    logger.info({ userId, weekId }, 'PickReminderJob complete');
  }
}
