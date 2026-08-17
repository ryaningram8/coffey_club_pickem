import type { FastifyReply, FastifyRequest } from 'fastify';
import { ForbiddenError, UnauthorizedError } from './errors';
import { prisma } from './prisma';
import { verifyAccessToken } from './tokens';

// Augment FastifyRequest so TypeScript knows about request.user
declare module 'fastify' {
  interface FastifyRequest {
    user: {
      id: string;
      isAdmin: boolean;
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
    request.user = { id: payload.sub, isAdmin: payload.isAdmin };
  } catch {
    throw new UnauthorizedError('Token expired or invalid');
  }
}

/**
 * Returns a preHandler restricted to the global admin. Implies
 * authentication — no need to also add authenticate().
 */
export function requireAdmin() {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    await authenticate(request, reply);
    if (!request.user.isAdmin) {
      throw new ForbiddenError('Admin access required');
    }
  };
}

/**
 * Returns a preHandler restricted to the global admin OR the commissioner of
 * a specific pool. `getSeasonId` resolves which pool from the request (e.g.
 * a param, or a lookup through a week/game id) — return `undefined` for
 * "no pool given," which falls back to admin-only (used by routes like
 * broadcast where an omitted pool means "everyone," an admin-only action).
 * Implies authentication.
 */
export function requirePoolCommissioner(
  getSeasonId: (request: FastifyRequest) => Promise<string | undefined>,
) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    await authenticate(request, reply);
    if (request.user.isAdmin) return;

    const seasonId = await getSeasonId(request);
    if (!seasonId) {
      throw new ForbiddenError('Admin access required');
    }

    const membership = await prisma.seasonMembership.findUnique({
      where: { userId_seasonId: { userId: request.user.id, seasonId } },
    });
    if (membership?.role !== 'commissioner') {
      throw new ForbiddenError('Commissioner access required for this pool');
    }
  };
}

/**
 * Returns a preHandler restricted to the global admin OR any member (player
 * or commissioner) of a specific pool — for read endpoints that expose a
 * pool's data (a week's games, its standings, individual picks) to whoever
 * happens to know or guess the ID, not just people who've actually joined.
 * Implies authentication.
 */
export function requirePoolMember(getSeasonId: (request: FastifyRequest) => Promise<string>) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    await authenticate(request, reply);
    if (request.user.isAdmin) return;

    const seasonId = await getSeasonId(request);
    const membership = await prisma.seasonMembership.findUnique({
      where: { userId_seasonId: { userId: request.user.id, seasonId } },
    });
    if (!membership) {
      throw new ForbiddenError('You are not a member of this pool');
    }
  };
}

/**
 * Returns a preHandler restricted to the global admin OR a commissioner of
 * at least one pool — for actions that aren't scoped to a specific pool
 * (e.g. browsing live ESPN game data before it's assigned anywhere).
 * Implies authentication.
 */
export function requireAnyCommissioner() {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    await authenticate(request, reply);
    if (request.user.isAdmin) return;

    const membership = await prisma.seasonMembership.findFirst({
      where: { userId: request.user.id, role: 'commissioner' },
    });
    if (!membership) {
      throw new ForbiddenError('Commissioner access required');
    }
  };
}
