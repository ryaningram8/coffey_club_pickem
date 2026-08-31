import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as pickService from '../services/pick.service';
import * as weekService from '../services/week.service';
import { authenticate, requirePoolCommissioner } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });
const idUserParams = z.object({ id: z.string().min(1), userId: z.string().min(1) });

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

  // Commissioner-only: paper pick sheet catch-up — read/write another
  // player's picks, no pick-deadline enforcement (see pick.service.ts).
  server.get(
    '/:id/players/:userId/picks',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id, userId } = idUserParams.parse(request.params);
      return pickService.getUserPicks(id, userId);
    },
  );

  server.put(
    '/:id/players/:userId/picks',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id, userId } = idUserParams.parse(request.params);
      const { picks } = submitPicksBody.parse(request.body);
      return pickService.submitPicksForPlayer(id, userId, picks);
    },
  );
}
