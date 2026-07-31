import { finalizeWeek } from '../services/results.service';
import { logger } from '../lib/logger';

/**
 * Computes weekly results and rolls up season standings once every game in
 * a week has reached a final (or cancelled) state. Idempotent — safe to
 * rerun, e.g. if ScoreSyncJob re-triggers it after a late score correction.
 */
export class WeekCompleteJob {
  async process(weekId: string): Promise<void> {
    logger.info({ weekId }, 'WeekCompleteJob starting');
    await finalizeWeek(weekId);
    logger.info({ weekId }, 'WeekCompleteJob complete');
  }
}
