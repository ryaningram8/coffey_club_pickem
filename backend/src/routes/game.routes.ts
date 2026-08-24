import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as gameService from '../services/game.service';
import * as weekService from '../services/week.service';
import { requireAnyCommissioner, requirePoolCommissioner } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

const availableQuery = z
  .object({
    sport: z.enum(['college', 'nfl', 'mlb']).optional(),
    startDate: z.string().date().optional(), // YYYY-MM-DD
    endDate: z.string().date().optional(), // YYYY-MM-DD
  })
  .refine((q) => (q.startDate == null) === (q.endDate == null), {
    message: 'startDate and endDate must be provided together',
  })
  .refine((q) => q.startDate == null || q.startDate <= q.endDate!, {
    message: 'startDate must not be after endDate',
  });

const updateGameBody = z.object({
  gameTime: z.string().datetime().optional(),
  spread: z.number().nullable().optional(),
  overUnder: z.number().nullable().optional(),
  status: z.enum(['scheduled', 'in_progress', 'final', 'postponed', 'cancelled']).optional(),
  displayOrder: z.number().int().optional(),
});

export async function gameRoutes(server: FastifyInstance) {
  server.get(
    '/available',
    { preHandler: requireAnyCommissioner() },
    async (request) => {
      const { sport, startDate, endDate } = availableQuery.parse(request.query);
      const dateRange =
        startDate && endDate ? { start: new Date(startDate), end: new Date(endDate) } : undefined;
      return gameService.getAvailableGames(sport, dateRange);
    },
  );

  server.put(
    '/:id',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForGame((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      const body = updateGameBody.parse(request.body);
      return weekService.updateGame(id, {
        ...body,
        gameTime: body.gameTime ? new Date(body.gameTime) : undefined,
      });
    },
  );

  server.delete(
    '/:id',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForGame((request.params as { id: string }).id),
      ),
    },
    async (request, reply) => {
      const { id } = idParams.parse(request.params);
      await weekService.deleteGame(id);
      return reply.code(204).send();
    },
  );
}
