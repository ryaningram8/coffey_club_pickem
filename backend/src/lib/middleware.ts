import type { FastifyReply, FastifyRequest } from 'fastify';
import type { Role } from '@prisma/client';
import { ForbiddenError, UnauthorizedError } from './errors';
import { verifyAccessToken } from './tokens';

// Augment FastifyRequest so TypeScript knows about request.user
declare module 'fastify' {
  interface FastifyRequest {
    user: {
      id: string;
      role: Role;
    };
  }
}

/**
 * Verifies the Bearer token in the Authorization header and
 * attaches the decoded payload to request.user.
 *
 * Usage: add as a preHandler on any protected route.
 */
export async function authenticate(
  request: FastifyRequest,
  _reply: FastifyReply,
): Promise<void> {
  const authHeader = request.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing or invalid Authorization header');
  }

  const token = authHeader.slice(7);
  try {
    const payload = verifyAccessToken(token);
    request.user = { id: payload.sub, role: payload.role };
  } catch {
    throw new UnauthorizedError('Token expired or invalid');
  }
}

/**
 * Returns a preHandler that enforces one of the given roles.
 * Implies authentication — no need to also add authenticate().
 *
 * Usage: preHandler: requireRole('commissioner', 'admin')
 */
export function requireRole(...roles: Role[]) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    await authenticate(request, reply);
    if (!roles.includes(request.user.role)) {
      throw new ForbiddenError('Insufficient permissions');
    }
  };
}
