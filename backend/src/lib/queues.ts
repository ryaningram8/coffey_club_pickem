import { Queue } from 'bullmq';
import { getRedisConnectionOptions } from './redis';

export const QUEUE_NAMES = {
  oddsRefresh: 'odds-refresh',
  scoreSync: 'score-sync',
  // Reserved for Phase 4:
  // notifications: 'notifications',
} as const;

export const oddsRefreshQueue = new Queue(QUEUE_NAMES.oddsRefresh, {
  connection: getRedisConnectionOptions(),
});

export const scoreSyncQueue = new Queue(QUEUE_NAMES.scoreSync, {
  connection: getRedisConnectionOptions(),
});
