import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as weekService from '../services/week.service';
import { authenticate, requirePoolCommissioner, requirePoolMember } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });
const currentWeekQuery = z.object({ seasonId: z.string().min(1) });

const updateWeekBody = z.object({
  label: z.string().min(1).max(100).optional(),
  pickDeadline: z.string().datetime().optional(),
  status: z.enum(['upcoming', 'picks_open', 'locked', 'in_progress', 'completed']).optional(),
  pot: z.number().nonnegative().nullable().optional(),
  commissionerMessage: z.string().max(500).nullable().optional(),
});

const assignGameTeam = z.object({
  espnId: z.string().min(1),
  name: z.string().min(1),
  abbreviation: z.string().min(1),
  logoUrl: z.string().nullable().optional(),
});

const assignGamesBody = z.object({
  games: z
    .array(
      z.object({
        espnGameId: z.string().min(1),
        sport: z.enum(['college', 'nfl']),
        gameTime: z.string().datetime(),
        homeTeam: assignGameTeam,
        awayTeam: assignGameTeam,
        spread: z.number().nullable().optional(),
        overUnder: z.number().nullable().optional(),
      }),
    )
    .min(1),
});

export async function weekRoutes(server: FastifyInstance) {
  server.get('/current', { preHandler: authenticate }, async (request) => {
    const { seasonId } = currentWeekQuery.parse(request.query);
    return weekService.getCurrentWeek(request.user.id, seasonId);
  });

  server.get(
    '/:id',
    {
      preHandler: requirePoolMember(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      return weekService.getWeekWithGames(id);
    },
  );

  server.put(
    '/:id',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      const body = updateWeekBody.parse(request.body);
      return weekService.updateWeek(id, {
        ...body,
        pickDeadline: body.pickDeadline ? new Date(body.pickDeadline) : undefined,
      });
    },
  );

  server.post(
    '/:id/games',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      const { games } = assignGamesBody.parse(request.body);
      return weekService.assignGames(
        id,
        games.map((g) => ({ ...g, gameTime: new Date(g.gameTime) })),
      );
    },
  );
}
