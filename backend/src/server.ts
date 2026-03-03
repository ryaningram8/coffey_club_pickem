import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import cookie from '@fastify/cookie';

import { logger } from './lib/logger';
import { registerRoutes } from './routes';

const server = Fastify({ logger });

async function start() {
  // Plugins
  await server.register(cors, {
    origin: process.env.APP_URL ?? 'http://localhost:3000',
    credentials: true,
  });

  await server.register(jwt, {
    secret: process.env.JWT_SECRET ?? 'dev-secret-change-in-production',
  });

  await server.register(cookie);

  // Routes
  await registerRoutes(server);

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
