import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as notificationService from '../services/notification.service';
import { authenticate } from '../lib/middleware';

const notificationPrefsBody = z.object({
  pickReminders: z
    .object({
      enabled: z.boolean().optional(),
      push: z.boolean().optional(),
      email: z.boolean().optional(),
      hoursBeforeDeadline: z.number().min(1).max(168).optional(),
    })
    .optional(),
  resultsNotifications: z
    .object({
      enabled: z.boolean().optional(),
      push: z.boolean().optional(),
      email: z.boolean().optional(),
    })
    .optional(),
});

const fcmTokenBody = z.object({
  token: z.string().min(1),
});

export async function userRoutes(server: FastifyInstance) {
  server.get(
    '/me/notifications',
    { preHandler: authenticate },
    async (request) => notificationService.getNotificationPrefs(request.user.id),
  );

  server.put(
    '/me/notifications',
    { preHandler: authenticate },
    async (request) => {
      const body = notificationPrefsBody.parse(request.body);
      return notificationService.updateNotificationPrefs(request.user.id, body);
    },
  );

  server.post(
    '/me/fcm-token',
    { preHandler: authenticate },
    async (request, reply) => {
      const { token } = fcmTokenBody.parse(request.body);
      await notificationService.registerFcmToken(request.user.id, token);
      return reply.code(204).send();
    },
  );
}
