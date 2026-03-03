import jwt from 'jsonwebtoken';
import type { Role } from '@prisma/client';

export interface AccessTokenPayload {
  sub: string;
  role: Role;
}

export interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
}

function getSecret(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required env var: ${key}`);
  return value;
}

export function signAccessToken(userId: string, role: Role): string {
  return jwt.sign(
    { sub: userId, role } satisfies AccessTokenPayload,
    getSecret('JWT_SECRET'),
    { expiresIn: '15m' },
  );
}

export function signRefreshToken(userId: string): string {
  return jwt.sign(
    { sub: userId, type: 'refresh' } satisfies RefreshTokenPayload,
    getSecret('JWT_REFRESH_SECRET'),
    { expiresIn: '30d' },
  );
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, getSecret('JWT_SECRET')) as AccessTokenPayload;
}

export function verifyRefreshToken(token: string): RefreshTokenPayload {
  const payload = jwt.verify(
    token,
    getSecret('JWT_REFRESH_SECRET'),
  ) as RefreshTokenPayload;
  if (payload.type !== 'refresh') throw new Error('Not a refresh token');
  return payload;
}
