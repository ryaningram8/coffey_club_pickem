import { FastifyInstance } from 'fastify';
import { z } from 'zod';

// Placeholder auth routes — full implementation in Phase 1 auth work.
// Structure follows: thin route handler → AuthService (business logic).

const signupSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(8).optional(),
  googleToken: z.string().optional(),
  inviteCode: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function authRoutes(server: FastifyInstance) {
  server.post('/signup', async (request, reply) => {
    const body = signupSchema.parse(request.body);
    // TODO: call AuthService.signup(body)
    return reply.code(201).send({ message: 'signup placeholder', data: body });
  });

  server.post('/login', async (request, reply) => {
    const body = loginSchema.parse(request.body);
    // TODO: call AuthService.login(body)
    return reply.code(200).send({ message: 'login placeholder', data: body });
  });

  server.post('/google', async (request, reply) => {
    // TODO: call AuthService.googleLogin(googleToken)
    return reply.code(200).send({ message: 'google login placeholder' });
  });

  server.post('/refresh', async (request, reply) => {
    // TODO: call AuthService.refreshToken(refreshToken from cookie)
    return reply.code(200).send({ message: 'refresh placeholder' });
  });
}
