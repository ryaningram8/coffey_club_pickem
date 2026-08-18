import type { FastifyInstance, FastifyReply } from 'fastify';
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

// Both optional: mobile sends refreshToken in the body (unchanged); web sends
// no body at all and relies on the httpOnly cookie the browser attaches
// automatically (see setRefreshCookie below).
const refreshBody = z.object({
  refreshToken: z.string().min(1).optional(),
});

const REFRESH_COOKIE_NAME = 'refreshToken';
const REFRESH_COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 30; // matches JWT_REFRESH_SECRET's 30d expiry

/**
 * Web's copy of the refresh token lives only in this HttpOnly cookie — never
 * in JS-readable storage — so an XSS bug can't read a credential that's
 * valid for a month. Mobile ignores it entirely (Dio has no cookie jar
 * configured) and keeps using the token also present in the JSON body.
 *
 * Path=/ rather than a narrower /auth: local dev hits this backend directly
 * with no prefix (`/auth/refresh`), while the containerized stack goes
 * through nginx's `/api/` proxy (`/api/auth/refresh` from the browser's
 * point of view, since Set-Cookie Path is matched against the browser's
 * request path, not the backend's internal one after nginx strips the
 * prefix). A single Path value has to work for both, so it's scoped broad
 * instead — the cookie is still HttpOnly/Secure/SameSite=Strict, so the
 * only cost of the wider path is a bit of unnecessary header overhead on
 * unrelated requests, not a new exposure.
 */
function setRefreshCookie(reply: FastifyReply, token: string, isDev: boolean) {
  reply.setCookie(REFRESH_COOKIE_NAME, token, {
    httpOnly: true,
    secure: !isDev,
    sameSite: 'strict',
    path: '/',
    maxAge: REFRESH_COOKIE_MAX_AGE_SECONDS,
  });
}

export async function authRoutes(server: FastifyInstance) {
  const isDev = process.env.NODE_ENV !== 'production';

  server.post(
    '/signup',
    // Guards against brute-forcing a valid invite code, not just repeat signups.
    { config: { rateLimit: { max: 5, timeWindow: '10 minutes' } } },
    async (request, reply) => {
      const body = signupBody.parse(request.body);
      const result = await authService.signup(body);
      setRefreshCookie(reply, result.tokens.refreshToken, isDev);
      return reply.code(201).send(result);
    },
  );

  server.post(
    '/login',
    { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const body = loginBody.parse(request.body);
      const result = await authService.login(body);
      setRefreshCookie(reply, result.tokens.refreshToken, isDev);
      return reply.code(200).send(result);
    },
  );

  server.post(
    '/google',
    { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const body = googleBody.parse(request.body);
      const result = await authService.googleAuth(body);
      setRefreshCookie(reply, result.tokens.refreshToken, isDev);
      return reply.code(200).send(result);
    },
  );

  server.post('/refresh', async (request, reply) => {
    const { refreshToken: bodyToken } = refreshBody.parse(request.body ?? {});
    const token = bodyToken ?? request.cookies[REFRESH_COOKIE_NAME];
    if (!token) throw new UnauthorizedError('Missing refresh token');

    let userId: string;
    try {
      const payload = verifyRefreshToken(token);
      userId = payload.sub;
    } catch {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }
    const tokens = await authService.refreshTokens(userId);
    setRefreshCookie(reply, tokens.refreshToken, isDev);
    return reply.code(200).send(tokens);
  });

  // No auth required — this only clears browser cookie state. There's no
  // server-side refresh-token revocation in this app (stateless JWTs), so
  // this is purely about web: without it, the httpOnly cookie set at login
  // would keep working for the full 30 days even after a client-side
  // "logout", since JS can't clear an HttpOnly cookie itself.
  server.post('/logout', async (_request, reply) => {
    reply.clearCookie(REFRESH_COOKIE_NAME, { path: '/' });
    return reply.code(204).send();
  });
}
