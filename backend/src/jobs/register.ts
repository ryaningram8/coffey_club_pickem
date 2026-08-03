import { Worker } from 'bullmq';
import { getRedisConnectionOptions } from '../lib/redis';
import { QUEUE_NAMES, oddsRefreshQueue, scoreSyncQueue } from '../lib/queues';
import { OddsRefreshJob } from './odds-refresh.job';
import { ScoreSyncJob } from './score-sync.job';
import { PickReminderJob } from './pick-reminder.job';
import { ResultsNotificationJob } from './results-notification.job';
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

  const scoreSyncWorker = new Worker(
    QUEUE_NAMES.scoreSync,
    async () => {
      await new ScoreSyncJob().process();
    },
    { connection: getRedisConnectionOptions() },
  );
  scoreSyncWorker.on('failed', (job, err) => {
    logger.error({ err, jobId: job?.id }, 'score-sync job failed');
  });

  scoreSyncQueue
    .add(
      'sync',
      {},
      {
        repeat: { pattern: '*/5 * * * 6,0' }, // every 5 min Sat & Sun
        jobId: 'score-sync-scheduled',
      },
    )
    .catch((err) => {
      logger.error({ err }, 'Failed to schedule score-sync job');
    });

  const notificationsWorker = new Worker(
    QUEUE_NAMES.notifications,
    async (job) => {
      const { userId, weekId } = job.data as { userId: string; weekId: string };
      if (job.name === 'pick-reminder') {
        await new PickReminderJob().process(userId, weekId);
      } else if (job.name === 'results-notification') {
        await new ResultsNotificationJob().process(userId, weekId);
      }
    },
    { connection: getRedisConnectionOptions() },
  );
  notificationsWorker.on('failed', (job, err) => {
    logger.error({ err, jobId: job?.id, jobName: job?.name }, 'notifications job failed');
  });
}
