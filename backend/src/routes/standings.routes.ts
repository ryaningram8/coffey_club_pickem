import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as resultsService from '../services/results.service';
import { authenticate } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

export async function weekStandingsRoutes(server: FastifyInstance) {
  server.get('/:id/standings', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return resultsService.getWeekStandings(id);
  });

  server.get('/:id/picks/summary', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return resultsService.getPicksSummary(id);
  });
}

export async function seasonStandingsRoutes(server: FastifyInstance) {
  server.get('/:id/standings', { preHandler: authenticate }, async (request) => {
    const { id } = idParams.parse(request.params);
    return resultsService.getSeasonStandings(id);
  });
}
