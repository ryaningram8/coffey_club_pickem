import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as resultsService from '../services/results.service';
import * as notificationService from '../services/notification.service';
import { requireRole } from '../lib/middleware';

const weekIdParams = z.object({ weekId: z.string().min(1) });

const markPayoutBody = z.object({
  userId: z.string().min(1),
  isPaid: z.boolean(),
});

const broadcastBody = z.object({
  title: z.string().min(1).max(200),
  message: z.string().min(1).max(2000),
  channels: z.array(z.enum(['push', 'email'])).min(1),
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

  server.post(
    '/broadcast',
    { preHandler: requireRole('commissioner', 'admin') },
    async (request) => {
      const body = broadcastBody.parse(request.body);
      return notificationService.broadcast(body);
    },
  );
}
