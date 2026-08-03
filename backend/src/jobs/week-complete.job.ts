import { finalizeWeek } from '../services/results.service';
import { scheduleResultsNotifications } from '../services/notification.service';
import { logger } from '../lib/logger';

/**
 * Computes weekly results and rolls up season standings once every game in
 * a week has reached a final (or cancelled) state. Idempotent — safe to
 * rerun, e.g. if ScoreSyncJob re-triggers it after a late score correction
 * (results-notification jobIds are deterministic per week/user, so a rerun
 * just no-ops on the already-queued jobs instead of double-sending).
 */
export class WeekCompleteJob {
  async process(weekId: string): Promise<void> {
    logger.info({ weekId }, 'WeekCompleteJob starting');
    await finalizeWeek(weekId);
    await scheduleResultsNotifications(weekId);
    logger.info({ weekId }, 'WeekCompleteJob complete');
  }
}
