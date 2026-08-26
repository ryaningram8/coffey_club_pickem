import crypto from 'node:crypto';
import { prisma } from '../lib/prisma';
import { ConflictError, NotFoundError, ValidationError } from '../lib/errors';

// Excludes visually ambiguous characters (0/O, 1/I/L) so codes are easy to
// read aloud or copy from a phone screen.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;
const MAX_BATCH_SIZE = 25;
const MAX_GENERATE_ATTEMPTS = 5;

export interface InvitationRedeemerDto {
  id: string;
  name: string;
  email: string;
  redeemedAt: string;
}

export interface InvitationDto {
  id: string;
  code: string;
  seasonId: string;
  seasonName: string;
  email: string | null;
  expiresAt: string | null;
  createdAt: string;
  maxUses: number | null;
  useCount: number;
  redeemedBy: InvitationRedeemerDto[];
}

function generateCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

function toInvitationDto(invitation: {
  id: string;
  code: string;
  seasonId: string | null;
  email: string | null;
  expiresAt: Date | null;
  createdAt: Date;
  maxUses: number | null;
  season: { name: string } | null;
  redemptions: { redeemedAt: Date; user: { id: string; name: string; email: string } }[];
}): InvitationDto {
  if (!invitation.seasonId || !invitation.season) {
    // Every invite minted through this service always carries a season;
    // only pre-existing legacy rows could lack one.
    throw new ValidationError('Invitation is missing a season');
  }
  return {
    id: invitation.id,
    code: invitation.code,
    seasonId: invitation.seasonId,
    seasonName: invitation.season.name,
    email: invitation.email,
    expiresAt: invitation.expiresAt?.toISOString() ?? null,
    createdAt: invitation.createdAt.toISOString(),
    maxUses: invitation.maxUses,
    useCount: invitation.redemptions.length,
    redeemedBy: invitation.redemptions.map((r) => ({
      id: r.user.id,
      name: r.user.name,
      email: r.user.email,
      redeemedAt: r.redeemedAt.toISOString(),
    })),
  };
}

const invitationInclude = {
  season: { select: { name: true } },
  redemptions: {
    include: { user: { select: { id: true, name: true, email: true } } },
    orderBy: { redeemedAt: 'asc' },
  },
} as const;

/**
 * Mints one or more invite codes for a season/pool. `count` generates an
 * anonymous batch (e.g. handing a few friends their own code each); `email`
 * targets a single code at one address instead (always single-use — a
 * targeted invite only ever makes sense for the one person it names).
 * `maxUses` controls how many different people can redeem an anonymous
 * code — omit (or pass 1) for the traditional one-person code, a higher
 * number (or `null` for unlimited) for one shared code handed to a whole
 * group at once. Codes are retried on the rare random collision against
 * the unique `code` column.
 */
export async function createInvitations(input: {
  seasonId: string;
  createdBy: string;
  email?: string;
  expiresAt?: Date;
  count?: number;
  maxUses?: number | null;
}): Promise<InvitationDto[]> {
  const season = await prisma.season.findUnique({ where: { id: input.seasonId } });
  if (!season) throw new NotFoundError('Season');

  const count = input.count ?? 1;
  if (count > 1 && input.email) {
    throw new ValidationError('Cannot target multiple codes at a single email');
  }
  if (count < 1 || count > MAX_BATCH_SIZE) {
    throw new ValidationError(`count must be between 1 and ${MAX_BATCH_SIZE}`);
  }
  if (input.maxUses !== undefined && input.maxUses !== null && input.maxUses < 1) {
    throw new ValidationError('maxUses must be at least 1');
  }
  if (input.email && input.maxUses !== undefined && input.maxUses !== 1) {
    throw new ValidationError('A code targeted at an email must be single-use');
  }
  // `??` would treat an explicit `null` (unlimited) the same as "omitted"
  // (default 1), so this checks `undefined` specifically instead.
  const maxUses = input.email ? 1 : input.maxUses === undefined ? 1 : input.maxUses;

  const created: InvitationDto[] = [];
  for (let i = 0; i < count; i++) {
    let attempt = 0;
    for (;;) {
      attempt++;
      try {
        const invitation = await prisma.invitation.create({
          data: {
            code: generateCode(),
            seasonId: input.seasonId,
            email: input.email ?? null,
            expiresAt: input.expiresAt ?? null,
            createdBy: input.createdBy,
            maxUses,
          },
          include: invitationInclude,
        });
        created.push(toInvitationDto(invitation));
        break;
      } catch (err) {
        const isUniqueViolation =
          typeof err === 'object' && err !== null && (err as { code?: string }).code === 'P2002';
        if (isUniqueViolation && attempt < MAX_GENERATE_ATTEMPTS) continue;
        throw err;
      }
    }
  }
  return created;
}

export async function listInvitations(seasonId?: string): Promise<InvitationDto[]> {
  const invitations = await prisma.invitation.findMany({
    where: { seasonId: seasonId ?? undefined },
    include: invitationInclude,
    orderBy: { createdAt: 'desc' },
  });
  return invitations.map(toInvitationDto);
}

/**
 * Lets an already-authenticated user join an additional pool via an invite
 * code, without creating a new account — the path for someone who joined a
 * preseason test pool to later join the main season once it opens. Also
 * the path a second (third, fourth, ...) person takes to redeem a shared
 * (maxUses > 1) code someone else already used.
 */
export async function redeemInvitation(
  code: string,
  userId: string,
): Promise<{ seasonId: string; seasonName: string }> {
  const invitation = await prisma.invitation.findUnique({
    where: { code },
    include: { redemptions: true },
  });
  if (!invitation) throw new ValidationError('Invalid invite code');
  if (invitation.redemptions.some((r) => r.userId === userId)) {
    throw new ValidationError('You have already used this invite code');
  }
  if (invitation.maxUses !== null && invitation.redemptions.length >= invitation.maxUses) {
    throw new ValidationError('Invite code has already been used');
  }
  if (invitation.expiresAt && invitation.expiresAt < new Date()) {
    throw new ValidationError('Invite code has expired');
  }
  if (invitation.email) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (user?.email !== invitation.email) {
      throw new ValidationError('This invite code is targeted at a different email');
    }
  }
  if (!invitation.seasonId) throw new ValidationError('Invitation is missing a season');

  const existingMembership = await prisma.seasonMembership.findUnique({
    where: { userId_seasonId: { userId, seasonId: invitation.seasonId } },
  });
  if (existingMembership) throw new ConflictError('You are already a member of this pool');

  const season = await prisma.$transaction(async (tx) => {
    // Re-check the cap inside the transaction to shrink (not eliminate) the
    // race window where two people redeem a nearly-exhausted shared code at
    // the same instant — acceptable for a 50-friend pick'em pool.
    const currentUses = await tx.invitationRedemption.count({ where: { invitationId: invitation.id } });
    if (invitation.maxUses !== null && currentUses >= invitation.maxUses) {
      throw new ValidationError('Invite code has already been used');
    }
    await tx.invitationRedemption.create({
      data: { invitationId: invitation.id, userId },
    });
    await tx.seasonMembership.create({
      data: { userId, seasonId: invitation.seasonId! },
    });
    return tx.season.findUniqueOrThrow({ where: { id: invitation.seasonId! } });
  });

  return { seasonId: season.id, seasonName: season.name };
}
