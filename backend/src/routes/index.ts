import { FastifyInstance } from 'fastify';

import { authRoutes } from './auth.routes';
import { seasonRoutes } from './season.routes';
import { weekRoutes } from './week.routes';
import { gameRoutes } from './game.routes';
import { pickRoutes } from './pick.routes';
import { pickSheetRoutes } from './pick-sheet.routes';
import { weekStandingsRoutes, seasonStandingsRoutes } from './standings.routes';
import { adminRoutes } from './admin.routes';
import { adminUsersRoutes } from './admin-users.routes';
import { userRoutes } from './user.routes';
import { invitationRoutes } from './invitation.routes';

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
  await server.register(pickSheetRoutes, { prefix: '/weeks' });
  await server.register(weekStandingsRoutes, { prefix: '/weeks' });
  await server.register(seasonStandingsRoutes, { prefix: '/seasons' });
  await server.register(adminRoutes, { prefix: '/admin' });
  await server.register(adminUsersRoutes, { prefix: '/admin/users' });
  await server.register(userRoutes, { prefix: '/users' });
  await server.register(invitationRoutes, { prefix: '/invitations' });
}
