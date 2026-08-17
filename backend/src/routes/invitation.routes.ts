import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as invitationService from '../services/invitation.service';
import { authenticate, requireAdmin } from '../lib/middleware';

const createInvitationsBody = z
  .object({
    seasonId: z.string().min(1),
    email: z.string().email().optional(),
    expiresAt: z.string().datetime().optional(),
    count: z.number().int().positive().optional(),
  })
  .refine((body) => !(body.email && body.count && body.count > 1), {
    message: 'Cannot target multiple codes at a single email',
  });

const listInvitationsQuery = z.object({
  seasonId: z.string().min(1).optional(),
});

const redeemParams = z.object({ code: z.string().min(1) });

export async function invitationRoutes(server: FastifyInstance) {
  server.post(
    '/',
    { preHandler: requireAdmin() },
    async (request, reply) => {
      const body = createInvitationsBody.parse(request.body);
      const invitations = await invitationService.createInvitations({
        seasonId: body.seasonId,
        createdBy: request.user.id,
        email: body.email,
        expiresAt: body.expiresAt ? new Date(body.expiresAt) : undefined,
        count: body.count,
      });
      return reply.code(201).send(invitations);
    },
  );

  server.get(
    '/',
    { preHandler: requireAdmin() },
    async (request) => {
      const { seasonId } = listInvitationsQuery.parse(request.query);
      return invitationService.listInvitations(seasonId);
    },
  );

  server.post('/:code/redeem', { preHandler: authenticate }, async (request) => {
    const { code } = redeemParams.parse(request.params);
    return invitationService.redeemInvitation(code, request.user.id);
  });
}
