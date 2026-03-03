import { FastifyInstance } from 'fastify';

import { authRoutes } from './auth.routes';

/**
 * Register all API route groups.
 * Add new route files here as each feature is built.
 */
export async function registerRoutes(server: FastifyInstance) {
  await server.register(authRoutes, { prefix: '/auth' });

  // Phase 2+: add these as implemented
  // await server.register(seasonRoutes, { prefix: '/seasons' });
  // await server.register(weekRoutes, { prefix: '/weeks' });
  // await server.register(gameRoutes, { prefix: '/games' });
  // await server.register(pickRoutes, { prefix: '/picks' });
  // await server.register(standingsRoutes, { prefix: '/standings' });
  // await server.register(invitationRoutes, { prefix: '/invitations' });
  // await server.register(adminRoutes, { prefix: '/admin' });
}
