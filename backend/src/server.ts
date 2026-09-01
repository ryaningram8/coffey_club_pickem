import Fastify, { type FastifyError, type FastifyReply, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';
import rateLimit from '@fastify/rate-limit';
import { ZodError } from 'zod';
import { AppError } from './lib/errors';
import { fastifyLoggerOptions } from './lib/logger';
import { registerRoutes } from './routes';
import { registerJobs } from './jobs/register';

const server = Fastify({ logger: fastifyLoggerOptions });

// Global error handler — must be registered before any plugin/route
// registration below. Fastify snapshots each child plugin's error-handler
// chain at the moment it's registered, so a handler set after
// `registerRoutes` never reaches routes registered earlier; they'd silently
// fall back to Fastify's own default `{statusCode, error, message}` shape
// instead of this app's `{ error, code }` convention.
server.setErrorHandler(
  (error: FastifyError | Error, request: FastifyRequest, reply: FastifyReply) => {
    if (error instanceof AppError) {
      reply.code(error.statusCode).send({ error: error.message, code: error.code });
      return;
    }
    if (error instanceof ZodError) {
      const message = error.errors
        .map((e) => `${e.path.join('.')}: ${e.message}`)
        .join(', ');
      reply.code(400).send({ error: message, code: 'VALIDATION_ERROR' });
      return;
    }
    // request.log (not the standalone logger) so this error carries the same
    // reqId as the request's own access log line — lets a player-reported
    // error be grepped straight to its exact request instead of matched by timestamp.
    request.log.error(error);
    reply
      .code(500)
      .send({ error: 'Internal server error', code: 'INTERNAL_ERROR', reqId: request.id });
  },
);

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

  await server.register(cookie);

  // The shared Flutter Dio client sends `Content-Type: application/json` on
  // every request (see ApiClient in api_client.dart), even no-body ones like
  // POST /invitations/:code/redeem — Fastify's default JSON parser rejects
  // an empty body outright when that header is present, so treat empty as
  // "no body" instead of a parse error.
  server.addContentTypeParser(
    'application/json',
    { parseAs: 'string' },
    (_request, body, done) => {
      if (body === '') {
        done(null, undefined);
        return;
      }
      try {
        done(null, JSON.parse(body as string));
      } catch (err) {
        done(err as Error, undefined);
      }
    },
  );

  // Global rate-limit safety net; auth routes set stricter per-route overrides
  // (see auth.routes.ts) since they're the actual brute-force/abuse surface.
  await server.register(rateLimit, {
    max: 200,
    timeWindow: '1 minute',
  });

  // Routes
  await registerRoutes(server);

  // Background jobs (BullMQ workers + repeatable schedules)
  registerJobs();

  // Health check
  server.get('/health', async () => ({ status: 'ok' }));

  // Start
  const port = parseInt(process.env.PORT ?? '4000', 10);
  await server.listen({ port, host: '0.0.0.0' });
}

start().catch((err) => {
  console.error(err);
  process.exit(1);
});
