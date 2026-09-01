import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as seasonService from '../services/season.service';
import * as weekService from '../services/week.service';
import { authenticate, requireAdmin, requirePoolCommissioner } from '../lib/middleware';

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

const createShellMemberBody = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export async function seasonRoutes(server: FastifyInstance) {
  server.get('/', { preHandler: requireAdmin() }, async () => {
    return seasonService.listSeasons();
  });

  server.get('/mine', { preHandler: authenticate }, async (request) => {
    return seasonService.listMySeasons(request.user.id);
  });

  server.get('/active', { preHandler: authenticate }, async (request) => {
    return seasonService.getActiveSeason(request.user.id);
  });

  server.get('/:id', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return seasonService.getSeason(id);
  });

  server.get('/:id/weeks', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return seasonService.listWeeks(id);
  });

  server.get(
    '/:id/members',
    { preHandler: requirePoolCommissioner(async (request) => (request.params as { id: string }).id) },
    async (request) => {
      const { id } = idParams.parse(request.params);
      return seasonService.getSeasonMembers(id);
    },
  );

  server.post(
    '/:id/members/shell',
    { preHandler: requirePoolCommissioner(async (request) => (request.params as { id: string }).id) },
    async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const body = createShellMemberBody.parse(request.body);
      const member = await seasonService.createShellMember(id, body);
      return reply.code(201).send(member);
    },
  );

  server.post('/', { preHandler: requireAdmin() }, async (request, reply) => {
    const body = createSeasonBody.parse(request.body);
    const season = await seasonService.createSeason(body);
    return reply.code(201).send(season);
  });

  server.put(
    '/:id',
    { preHandler: requirePoolCommissioner(async (request) => (request.params as { id: string }).id) },
    async (request) => {
      const { id } = idParams.parse(request.params);
      const body = updateSeasonBody.parse(request.body);
      return seasonService.updateSeason(id, body);
    },
  );

  server.post(
    '/:id/weeks',
    { preHandler: requirePoolCommissioner(async (request) => (request.params as { id: string }).id) },
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
