import type { PoolRole } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { NotFoundError } from '../lib/errors';

export interface AdminMembershipDto {
  seasonId: string;
  seasonName: string;
  role: PoolRole;
  joinedAt: string;
}

export interface AdminUserDto {
  id: string;
  name: string;
  email: string;
  isAdmin: boolean;
  memberships: AdminMembershipDto[];
}

const membershipInclude = { season: { select: { name: true } } } as const;

function toMembershipDto(membership: {
  seasonId: string;
  role: PoolRole;
  joinedAt: Date;
  season: { name: string };
}): AdminMembershipDto {
  return {
    seasonId: membership.seasonId,
    seasonName: membership.season.name,
    role: membership.role,
    joinedAt: membership.joinedAt.toISOString(),
  };
}

/** Every user in the system with their per-pool memberships — admin's user-management view. */
export async function listUsersWithMemberships(): Promise<AdminUserDto[]> {
  const users = await prisma.user.findMany({
    orderBy: { name: 'asc' },
    include: {
      seasonMemberships: { include: membershipInclude, orderBy: { joinedAt: 'asc' } },
    },
  });
  return users.map((u) => ({
    id: u.id,
    name: u.name,
    email: u.email,
    isAdmin: u.isAdmin,
    memberships: u.seasonMemberships.map(toMembershipDto),
  }));
}

/** Promotes/demotes a user's standing within a pool they're already a member of. */
export async function updateMembershipRole(
  userId: string,
  seasonId: string,
  role: PoolRole,
): Promise<AdminMembershipDto> {
  const existing = await prisma.seasonMembership.findUnique({
    where: { userId_seasonId: { userId, seasonId } },
  });
  if (!existing) throw new NotFoundError('Pool membership');

  const updated = await prisma.seasonMembership.update({
    where: { userId_seasonId: { userId, seasonId } },
    data: { role },
    include: membershipInclude,
  });
  return toMembershipDto(updated);
}

/** Removes a user from a pool. Their historical picks/results for it are untouched. */
export async function removeMembership(userId: string, seasonId: string): Promise<void> {
  const existing = await prisma.seasonMembership.findUnique({
    where: { userId_seasonId: { userId, seasonId } },
  });
  if (!existing) throw new NotFoundError('Pool membership');
  await prisma.seasonMembership.delete({ where: { userId_seasonId: { userId, seasonId } } });
}
