import Fastify, { type FastifyError, type FastifyReply, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import { ZodError } from 'zod';
import { AppError } from './lib/errors';
import { logger } from './lib/logger';
import { registerRoutes } from './routes';

const server = Fastify({ logger });

async function start() {
  // Plugins
  const isDev = process.env.NODE_ENV !== 'production';
  await server.register(cors, {
    // In dev, allow any localhost origin (Flutter picks a random port).
    // In production, restrict to APP_URL.
    origin: isDev
      ? (origin, cb) => {
          if (!origin || /^https?:\/\/localhost(:\d+)?$/.test(origin)) {
            cb(null, true);
          } else {
            cb(new Error('Not allowed by CORS'), false);
          }
        }
      : process.env.APP_URL ?? 'http://localhost:3000',
    credentials: true,
  });

  // Routes
  await registerRoutes(server);

  // Health check
  server.get('/health', async () => ({ status: 'ok' }));

  // Global error handler
  server.setErrorHandler(
    (error: FastifyError | Error, _request: FastifyRequest, reply: FastifyReply) => {
      if (error instanceof AppError) {
        return reply.code(error.statusCode).send({ error: error.message, code: error.code });
      }
      if (error instanceof ZodError) {
        const message = error.errors
          .map((e) => `${e.path.join('.')}: ${e.message}`)
          .join(', ');
        return reply.code(400).send({ error: message, code: 'VALIDATION_ERROR' });
      }
      logger.error(error);
      return reply.code(500).send({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    },
  );

  // Start
  const port = parseInt(process.env.PORT ?? '4000', 10);
  await server.listen({ port, host: '0.0.0.0' });
}

start().catch((err) => {
  console.error(err);
  process.exit(1);
});
