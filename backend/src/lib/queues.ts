import { Queue } from 'bullmq';
import { getRedisConnectionOptions } from './redis';

export const QUEUE_NAMES = {
  oddsRefresh: 'odds-refresh',
  // Reserved for Phase 3 / Phase 4:
  // scoreSync: 'score-sync',
  // notifications: 'notifications',
} as const;

export const oddsRefreshQueue = new Queue(QUEUE_NAMES.oddsRefresh, {
  connection: getRedisConnectionOptions(),
});
