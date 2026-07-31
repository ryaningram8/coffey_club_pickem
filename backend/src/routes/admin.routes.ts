import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as resultsService from '../services/results.service';
import { requireRole } from '../lib/middleware';

const weekIdParams = z.object({ weekId: z.string().min(1) });

const markPayoutBody = z.object({
  userId: z.string().min(1),
  isPaid: z.boolean(),
});

export async function adminRoutes(server: FastifyInstance) {
  server.post(
    '/payouts/:weekId/mark',
    { preHandler: requireRole('commissioner', 'admin') },
    async (request) => {
      const { weekId } = weekIdParams.parse(request.params);
      const { userId, isPaid } = markPayoutBody.parse(request.body);
      return resultsService.markPayout(weekId, userId, isPaid);
    },
  );
}
