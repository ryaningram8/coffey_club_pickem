import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as gameService from '../services/game.service';
import * as weekService from '../services/week.service';
import { requireRole } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

const availableQuery = z.object({
  sport: z.enum(['college', 'nfl']).optional(),
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
    { preHandler: requireRole('commissioner', 'admin') },
    async (request) => {
      const { sport } = availableQuery.parse(request.query);
      return gameService.getAvailableGames(sport);
    },
  );

  server.put(
    '/:id',
    { preHandler: requireRole('commissioner', 'admin') },
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
    { preHandler: requireRole('commissioner', 'admin') },
    async (request, reply) => {
      const { id } = idParams.parse(request.params);
      await weekService.deleteGame(id);
      return reply.code(204).send();
    },
  );
}
