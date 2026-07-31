/**
 * BullMQ bundles its own nested `ioredis` dependency, which is a distinct
 * (structurally incompatible) type from a standalone `ioredis` instance
 * when both packages end up installed side by side. Passing a plain options
 * object instead of an `ioredis` instance sidesteps that entirely — BullMQ
 * builds its own internal connection from it.
 */
export function getRedisConnectionOptions(): {
  host: string;
  port: number;
  password?: string;
  maxRetriesPerRequest: null;
} {
  const url = process.env.REDIS_URL;
  if (!url) throw new Error('Missing required env var: REDIS_URL');

  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : 6379,
    password: parsed.password || undefined,
    // Required by BullMQ workers so it can manage retries itself.
    maxRetriesPerRequest: null,
  };
}
