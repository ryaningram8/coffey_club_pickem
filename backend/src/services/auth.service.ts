import bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
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
  isAdmin: boolean;
  venmoHandle: string | null;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function issueTokens(userId: string, isAdmin: boolean): AuthTokens {
  return {
    accessToken: signAccessToken(userId, isAdmin),
    refreshToken: signRefreshToken(userId),
  };
}

function toUserDto(user: {
  id: string;
  email: string;
  name: string;
  isAdmin: boolean;
  venmoHandle: string | null;
}): UserDto {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    isAdmin: user.isAdmin,
    venmoHandle: user.venmoHandle,
  };
}

async function validateInviteCode(code: string) {
  const invitation = await prisma.invitation.findUnique({
    where: { code },
    include: { _count: { select: { redemptions: true } } },
  });
  if (!invitation) throw new ValidationError('Invalid invite code');
  if (invitation.maxUses !== null && invitation._count.redemptions >= invitation.maxUses) {
    throw new ValidationError('Invite code has already been used');
  }
  if (invitation.expiresAt && invitation.expiresAt < new Date()) {
    throw new ValidationError('Invite code has expired');
  }
  return invitation;
}

// ─── Service functions ────────────────────────────────────────────────────────

export async function signup(input: {
  name: string;
  email: string;
  password: string;
  inviteCode: string;
}): Promise<{ tokens: AuthTokens; user: UserDto }> {
  const invitation = await validateInviteCode(input.inviteCode);

  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing && !existing.isShellAccount) {
    throw new ConflictError('An account with this email already exists');
  }

  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);

  const user = await prisma.$transaction(async (tx) => {
    // Re-check the cap inside the transaction to shrink (not eliminate) the
    // race window where two signups redeem a nearly-exhausted shared code
    // at the same instant — acceptable for a 50-friend pick'em pool.
    const currentUses = await tx.invitationRedemption.count({ where: { invitationId: invitation.id } });
    if (invitation.maxUses !== null && currentUses >= invitation.maxUses) {
      throw new ValidationError('Invite code has already been used');
    }

    // Claiming a commissioner-created shell account: update the existing row
    // in place (same id) so Picks/WeeklyResults/SeasonStandings entered
    // against it while unclaimed stay attached, rather than creating a
    // second, empty account for the same person.
    const newUser = existing
      ? await tx.user.update({
          where: { id: existing.id },
          data: { name: input.name, passwordHash, isShellAccount: false },
        })
      : await tx.user.create({
          data: { email: input.email, name: input.name, passwordHash },
        });
    await tx.invitationRedemption.create({
      data: { invitationId: invitation.id, userId: newUser.id },
    });
    if (invitation.seasonId) {
      // The shell account may already be a member of this season (it's the
      // common case — the commissioner created it there to enter picks) —
      // skip the insert then, since [userId, seasonId] is unique.
      const alreadyMember = existing
        ? await tx.seasonMembership.findUnique({
            where: { userId_seasonId: { userId: newUser.id, seasonId: invitation.seasonId } },
          })
        : null;
      if (!alreadyMember) {
        await tx.seasonMembership.create({
          data: { userId: newUser.id, seasonId: invitation.seasonId },
        });
      }
    }
    return newUser;
  });

  return { tokens: issueTokens(user.id, user.isAdmin), user: toUserDto(user) };
}

export async function login(input: {
  email: string;
  password: string;
}): Promise<{ tokens: AuthTokens; user: UserDto }> {
  const user = await prisma.user.findUnique({ where: { email: input.email } });
  if (!user?.passwordHash) throw new UnauthorizedError('Invalid email or password');

  const valid = await bcrypt.compare(input.password, user.passwordHash);
  if (!valid) throw new UnauthorizedError('Invalid email or password');

  return { tokens: issueTokens(user.id, user.isAdmin), user: toUserDto(user) };
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
        // Claiming a shell account: replace the commissioner-entered
        // placeholder name with the real one and flip it to a real account.
        // A real account's existing name is left untouched.
        data: emailUser.isShellAccount
          ? { googleId, name, isShellAccount: false }
          : { googleId },
      });
    } else if (input.inviteCode) {
      // New user with an invite code already in hand (e.g. a deep-linked
      // signup) — join the pool immediately as part of account creation.
      const invitation = await validateInviteCode(input.inviteCode);

      user = await prisma.$transaction(async (tx) => {
        const currentUses = await tx.invitationRedemption.count({ where: { invitationId: invitation.id } });
        if (invitation.maxUses !== null && currentUses >= invitation.maxUses) {
          throw new ValidationError('Invite code has already been used');
        }
        const newUser = await tx.user.create({
          data: { email, name, googleId },
        });
        await tx.invitationRedemption.create({
          data: { invitationId: invitation.id, userId: newUser.id },
        });
        if (invitation.seasonId) {
          await tx.seasonMembership.create({
            data: { userId: newUser.id, seasonId: invitation.seasonId },
          });
        }
        return newUser;
      });
    } else {
      // New user, no invite code yet — create the account so Google
      // sign-in succeeds. They land with zero pools; PoolSwitcherBar's
      // "Join a pool" flow (redeemInvitation) is how they actually get in.
      user = await prisma.user.create({ data: { email, name, googleId } });
    }
  }

  return { tokens: issueTokens(user.id, user.isAdmin), user: toUserDto(user) };
}

export async function refreshTokens(userId: string): Promise<AuthTokens> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new UnauthorizedError('User not found');
  return issueTokens(user.id, user.isAdmin);
}
