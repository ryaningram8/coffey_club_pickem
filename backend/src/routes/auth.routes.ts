import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as authService from '../services/auth.service';
import { verifyRefreshToken } from '../lib/tokens';
import { UnauthorizedError } from '../lib/errors';

const signupBody = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  password: z.string().min(8),
  inviteCode: z.string().min(1),
});

const loginBody = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const googleBody = z.object({
  googleToken: z.string().min(1),
  inviteCode: z.string().min(1).optional(),
});

const refreshBody = z.object({
  refreshToken: z.string().min(1),
});

export async function authRoutes(server: FastifyInstance) {
  server.post('/signup', async (request, reply) => {
    const body = signupBody.parse(request.body);
    const result = await authService.signup(body);
    return reply.code(201).send(result);
  });

  server.post('/login', async (request, reply) => {
    const body = loginBody.parse(request.body);
    const result = await authService.login(body);
    return reply.code(200).send(result);
  });

  server.post('/google', async (request, reply) => {
    const body = googleBody.parse(request.body);
    const result = await authService.googleAuth(body);
    return reply.code(200).send(result);
  });

  server.post('/refresh', async (request, reply) => {
    const { refreshToken } = refreshBody.parse(request.body);
    let userId: string;
    try {
      const payload = verifyRefreshToken(refreshToken);
      userId = payload.sub;
    } catch {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }
    const tokens = await authService.refreshTokens(userId);
    return reply.code(200).send(tokens);
  });
}
