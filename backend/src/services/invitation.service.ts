import crypto from 'node:crypto';
import { prisma } from '../lib/prisma';
import { ConflictError, NotFoundError, ValidationError } from '../lib/errors';

// Excludes visually ambiguous characters (0/O, 1/I/L) so codes are easy to
// read aloud or copy from a phone screen.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;
const MAX_BATCH_SIZE = 25;
const MAX_GENERATE_ATTEMPTS = 5;

export interface InvitationDto {
  id: string;
  code: string;
  seasonId: string;
  seasonName: string;
  email: string | null;
  expiresAt: string | null;
  createdAt: string;
  usedAt: string | null;
  usedBy: { id: string; name: string; email: string } | null;
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
  usedAt: Date | null;
  season: { name: string } | null;
  user: { id: string; name: string; email: string } | null;
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
    usedAt: invitation.usedAt?.toISOString() ?? null,
    usedBy: invitation.user,
  };
}

const invitationInclude = {
  season: { select: { name: true } },
  user: { select: { id: true, name: true, email: true } },
} as const;

/**
 * Mints one or more single-use invite codes for a season/pool. `count`
 * generates an anonymous batch (e.g. handing a few friends their own code
 * each); `email` targets a single code at one address instead. Codes are
 * retried on the rare random collision against the unique `code` column.
 */
export async function createInvitations(input: {
  seasonId: string;
  createdBy: string;
  email?: string;
  expiresAt?: Date;
  count?: number;
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
 * preseason test pool to later join the main season once it opens.
 */
export async function redeemInvitation(
  code: string,
  userId: string,
): Promise<{ seasonId: string; seasonName: string }> {
  const invitation = await prisma.invitation.findUnique({ where: { code } });
  if (!invitation) throw new ValidationError('Invalid invite code');
  if (invitation.usedBy) throw new ValidationError('Invite code has already been used');
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
    await tx.invitation.update({
      where: { code },
      data: { usedBy: userId, usedAt: new Date() },
    });
    await tx.seasonMembership.create({
      data: { userId, seasonId: invitation.seasonId! },
    });
    return tx.season.findUniqueOrThrow({ where: { id: invitation.seasonId! } });
  });

  return { seasonId: season.id, seasonName: season.name };
}
