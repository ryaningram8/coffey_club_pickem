import { sendResultsNotification } from '../services/notification.service';
import { logger } from '../lib/logger';

/**
 * Sends one user their finalized results for one week. Enqueued (jobName
 * 'results-notification' on the shared notifications queue) for every
 * participant right after WeekCompleteJob finishes.
 */
export class ResultsNotificationJob {
  async process(userId: string, weekId: string): Promise<void> {
    logger.info({ userId, weekId }, 'ResultsNotificationJob starting');
    await sendResultsNotification(userId, weekId);
    logger.info({ userId, weekId }, 'ResultsNotificationJob complete');
  }
}
