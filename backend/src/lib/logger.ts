import pino from 'pino';

const isDev = process.env.NODE_ENV !== 'production';

const pinoOptions = isDev
  ? {
      transport: {
        target: 'pino-pretty',
        options: { colorize: true },
      },
    }
  : {};

/** Passed to `Fastify({ logger: ... })` — Fastify builds its own pino instance from this. */
export const fastifyLoggerOptions = isDev ? pinoOptions : true;

/** Standalone logger for use outside request handlers (jobs, clients, startup). */
export const logger = pino(pinoOptions);
