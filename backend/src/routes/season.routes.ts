import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as seasonService from '../services/season.service';
import * as weekService from '../services/week.service';
import { authenticate, requireRole } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

const createSeasonBody = z.object({
  name: z.string().min(1).max(100),
  year: z.number().int(),
  entryFee: z.number().nonnegative().optional(),
  payout1stPct: z.number().nonnegative().optional(),
  payout2ndPct: z.number().nonnegative().optional(),
  payout3rdPct: z.number().nonnegative().optional(),
  defaultWeeklyPot: z.number().nonnegative().optional(),
});

const updateSeasonBody = z.object({
  name: z.string().min(1).max(100).optional(),
  status: z.enum(['upcoming', 'active', 'completed']).optional(),
  entryFee: z.number().nonnegative().optional(),
  payout1stPct: z.number().nonnegative().optional(),
  payout2ndPct: z.number().nonnegative().optional(),
  payout3rdPct: z.number().nonnegative().optional(),
  defaultWeeklyPot: z.number().nonnegative().nullable().optional(),
});

const createWeekBody = z.object({
  weekNumber: z.number().int().positive(),
  label: z.string().min(1).max(100),
  pickDeadline: z.string().datetime(),
});

export async function seasonRoutes(server: FastifyInstance) {
  server.get('/active', { preHandler: authenticate }, async () => {
    return seasonService.getActiveSeason();
  });

  server.get('/:id', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return seasonService.getSeason(id);
  });

  server.get('/:id/weeks', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return seasonService.listWeeks(id);
  });

  server.post('/', { preHandler: requireRole('admin') }, async (request, reply) => {
    const body = createSeasonBody.parse(request.body);
    const season = await seasonService.createSeason(body);
    return reply.code(201).send(season);
  });

  server.put(
    '/:id',
    { preHandler: requireRole('commissioner', 'admin') },
    async (request) => {
      const { id } = idParams.parse(request.params);
      const body = updateSeasonBody.parse(request.body);
      return seasonService.updateSeason(id, body);
    },
  );

  server.post(
    '/:id/weeks',
    { preHandler: requireRole('commissioner', 'admin') },
    async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const body = createWeekBody.parse(request.body);
      const week = await weekService.createWeek(id, {
        ...body,
        pickDeadline: new Date(body.pickDeadline),
      });
      return reply.code(201).send(week);
    },
  );
}
