import { Worker } from 'bullmq';
import { getRedisConnectionOptions } from '../lib/redis';
import { QUEUE_NAMES, oddsRefreshQueue } from '../lib/queues';
import { OddsRefreshJob } from './odds-refresh.job';
import { logger } from '../lib/logger';

/**
 * Registers BullMQ workers and schedules repeatable jobs.
 * Call once at server startup.
 */
export function registerJobs(): void {
  const oddsWorker = new Worker(
    QUEUE_NAMES.oddsRefresh,
    async () => {
      await new OddsRefreshJob().process();
    },
    { connection: getRedisConnectionOptions() },
  );
  oddsWorker.on('failed', (job, err) => {
    logger.error({ err, jobId: job?.id }, 'odds-refresh job failed');
  });

  oddsRefreshQueue
    .add(
      'refresh',
      {},
      {
        repeat: { pattern: '0 8 * * 1-5' }, // 8am Mon–Fri
        jobId: 'odds-refresh-scheduled',
      },
    )
    .catch((err) => {
      logger.error({ err }, 'Failed to schedule odds-refresh job');
    });
}
