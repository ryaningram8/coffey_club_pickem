import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as pickService from '../services/pick.service';
import { authenticate } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

const submitPicksBody = z.object({
  picks: z
    .array(
      z.object({
        gameId: z.string().min(1),
        pickedTeamId: z.string().min(1),
      }),
    )
    .min(1),
});

export async function pickRoutes(server: FastifyInstance) {
  server.get('/:id/picks', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return pickService.getUserPicks(id, request.user.id);
  });

  server.post('/:id/picks', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    const { picks } = submitPicksBody.parse(request.body);
    return pickService.submitPicks(id, request.user.id, picks);
  });
}
