import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as userManagementService from '../services/user-management.service';
import { requireAdmin } from '../lib/middleware';

const membershipParams = z.object({
  userId: z.string().min(1),
  seasonId: z.string().min(1),
});

const updateRoleBody = z.object({
  role: z.enum(['player', 'commissioner']),
});

export async function adminUsersRoutes(server: FastifyInstance) {
  server.get('/', { preHandler: requireAdmin() }, async () => {
    return userManagementService.listUsersWithMemberships();
  });

  server.put(
    '/:userId/memberships/:seasonId',
    { preHandler: requireAdmin() },
    async (request) => {
      const { userId, seasonId } = membershipParams.parse(request.params);
      const { role } = updateRoleBody.parse(request.body);
      return userManagementService.updateMembershipRole(userId, seasonId, role);
    },
  );

  server.delete(
    '/:userId/memberships/:seasonId',
    { preHandler: requireAdmin() },
    async (request, reply) => {
      const { userId, seasonId } = membershipParams.parse(request.params);
      await userManagementService.removeMembership(userId, seasonId);
      return reply.code(204).send();
    },
  );
}
