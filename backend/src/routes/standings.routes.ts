import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as resultsService from '../services/results.service';
import * as weekService from '../services/week.service';
import { requirePoolMember } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

export async function weekStandingsRoutes(server: FastifyInstance) {
  server.get(
    '/:id/standings',
    {
      preHandler: requirePoolMember(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      return resultsService.getWeekStandings(id);
    },
  );

  server.get(
    '/:id/picks/summary',
    {
      preHandler: requirePoolMember(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request) => {
      const { id } = idParams.parse(request.params);
      return resultsService.getPicksSummary(id);
    },
  );
}

export async function seasonStandingsRoutes(server: FastifyInstance) {
  server.get(
    '/:id/standings',
    { preHandler: requirePoolMember(async (request) => (request.params as { id: string }).id) },
    async (request) => {
      const { id } = idParams.parse(request.params);
      return resultsService.getSeasonStandings(id);
    },
  );
}
