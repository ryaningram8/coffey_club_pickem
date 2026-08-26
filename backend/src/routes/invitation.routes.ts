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
    // How many different people may redeem one code. Omit (or 1) for a
    // traditional one-person code; a higher number, or null for unlimited,
    // makes one shared code usable by a whole group (e.g. a single email
    // blast to all 100 pool members). Ignored/forced to 1 when `email` is
    // set — a targeted invite only ever makes sense for the one person it
    // names.
    maxUses: z.number().int().positive().nullable().optional(),
  })
  .refine((body) => !(body.email && body.count && body.count > 1), {
    message: 'Cannot target multiple codes at a single email',
  })
  .refine((body) => !(body.email && body.maxUses !== undefined && body.maxUses !== 1), {
    message: 'A code targeted at an email must be single-use',
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
        maxUses: body.maxUses,
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
