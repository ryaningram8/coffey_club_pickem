import bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import type { Role } from '@prisma/client';
import { prisma } from '../lib/prisma';
import {
  ConflictError,
  UnauthorizedError,
  ValidationError,
} from '../lib/errors';
import { signAccessToken, signRefreshToken } from '../lib/tokens';

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const BCRYPT_ROUNDS = 12;

// ─── Types ────────────────────────────────────────────────────────────────────

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface UserDto {
  id: string;
  email: string;
  name: string;
  role: Role;
  venmoHandle: string | null;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function issueTokens(userId: string, role: Role): AuthTokens {
  return {
    accessToken: signAccessToken(userId, role),
    refreshToken: signRefreshToken(userId),
  };
}

function toUserDto(user: {
  id: string;
  email: string;
  name: string;
  role: Role;
  venmoHandle: string | null;
}): UserDto {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    venmoHandle: user.venmoHandle,
  };
}

async function validateInviteCode(code: string): Promise<void> {
  const invitation = await prisma.invitation.findUnique({ where: { code } });
  if (!invitation) throw new ValidationError('Invalid invite code');
  if (invitation.usedBy) throw new ValidationError('Invite code has already been used');
  if (invitation.expiresAt && invitation.expiresAt < new Date()) {
    throw new ValidationError('Invite code has expired');
  }
}

// ─── Service functions ────────────────────────────────────────────────────────

export async function signup(input: {
  name: string;
  email: string;
  password: string;
  inviteCode: string;
}): Promise<{ tokens: AuthTokens; user: UserDto }> {
  await validateInviteCode(input.inviteCode);

  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) throw new ConflictError('An account with this email already exists');

  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);

  const user = await prisma.$transaction(async (tx) => {
    const newUser = await tx.user.create({
      data: { email: input.email, name: input.name, passwordHash },
    });
    await tx.invitation.update({
      where: { code: input.inviteCode },
      data: { usedBy: newUser.id, usedAt: new Date() },
    });
    return newUser;
  });

  return { tokens: issueTokens(user.id, user.role), user: toUserDto(user) };
}

export async function login(input: {
  email: string;
  password: string;
}): Promise<{ tokens: AuthTokens; user: UserDto }> {
  const user = await prisma.user.findUnique({ where: { email: input.email } });
  if (!user?.passwordHash) throw new UnauthorizedError('Invalid email or password');

  const valid = await bcrypt.compare(input.password, user.passwordHash);
  if (!valid) throw new UnauthorizedError('Invalid email or password');

  return { tokens: issueTokens(user.id, user.role), user: toUserDto(user) };
}

export async function googleAuth(input: {
  googleToken: string;
  inviteCode?: string;
}): Promise<{ tokens: AuthTokens; user: UserDto }> {
  // Verify the Google ID token
  let googleId: string;
  let email: string;
  let name: string;

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken: input.googleToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) throw new Error('Missing payload fields');
    googleId = payload.sub;
    email = payload.email;
    name = payload.name ?? email.split('@')[0];
  } catch {
    throw new UnauthorizedError('Invalid Google token');
  }

  // Find existing user by googleId
  let user = await prisma.user.findUnique({ where: { googleId } });

  if (!user) {
    // Try to link to an existing email account
    const emailUser = await prisma.user.findUnique({ where: { email } });
    if (emailUser) {
      user = await prisma.user.update({
        where: { id: emailUser.id },
        data: { googleId },
      });
    } else {
      // New user — invite code required
      if (!input.inviteCode) {
        throw new ValidationError('An invite code is required to create a new account');
      }
      await validateInviteCode(input.inviteCode);

      user = await prisma.$transaction(async (tx) => {
        const newUser = await tx.user.create({
          data: { email, name, googleId },
        });
        await tx.invitation.update({
          where: { code: input.inviteCode! },
          data: { usedBy: newUser.id, usedAt: new Date() },
        });
        return newUser;
      });
    }
  }

  return { tokens: issueTokens(user.id, user.role), user: toUserDto(user) };
}

export async function refreshTokens(userId: string): Promise<AuthTokens> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new UnauthorizedError('User not found');
  return issueTokens(user.id, user.role);
}
