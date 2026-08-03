import { FastifyInstance } from 'fastify';

import { authRoutes } from './auth.routes';
import { seasonRoutes } from './season.routes';
import { weekRoutes } from './week.routes';
import { gameRoutes } from './game.routes';
import { pickRoutes } from './pick.routes';
import { weekStandingsRoutes, seasonStandingsRoutes } from './standings.routes';
import { adminRoutes } from './admin.routes';
import { userRoutes } from './user.routes';

/**
 * Register all API route groups.
 * Add new route files here as each feature is built.
 */
export async function registerRoutes(server: FastifyInstance) {
  await server.register(authRoutes, { prefix: '/auth' });
  await server.register(seasonRoutes, { prefix: '/seasons' });
  await server.register(weekRoutes, { prefix: '/weeks' });
  await server.register(gameRoutes, { prefix: '/games' });
  await server.register(pickRoutes, { prefix: '/weeks' });
  await server.register(weekStandingsRoutes, { prefix: '/weeks' });
  await server.register(seasonStandingsRoutes, { prefix: '/seasons' });
  await server.register(adminRoutes, { prefix: '/admin' });
  await server.register(userRoutes, { prefix: '/users' });

  // Phase 4: add these as implemented
  // await server.register(invitationRoutes, { prefix: '/invitations' });
}
