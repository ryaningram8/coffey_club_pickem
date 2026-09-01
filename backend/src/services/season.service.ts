import type { PoolRole, Season, SeasonStatus } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { ConflictError, NotFoundError } from '../lib/errors';
import { toWeekSummaryDto, type WeekSummaryDto } from './week.service';

export interface SeasonDto {
  id: string;
  name: string;
  year: number;
  status: SeasonStatus;
  entryFee: string;
  payout1stPct: string;
  payout2ndPct: string;
  payout3rdPct: string;
  defaultWeeklyPot: string | null;
}

export interface MySeasonDto extends SeasonDto {
  myRole: PoolRole;
}

function toSeasonDto(season: Season): SeasonDto {
  return {
    id: season.id,
    name: season.name,
    year: season.year,
    status: season.status,
    entryFee: season.entryFee.toString(),
    payout1stPct: season.payout1stPct.toString(),
    payout2ndPct: season.payout2ndPct.toString(),
    payout3rdPct: season.payout3rdPct.toString(),
    defaultWeeklyPot: season.defaultWeeklyPot?.toString() ?? null,
  };
}

export async function getSeason(id: string): Promise<SeasonDto> {
  const season = await prisma.season.findUnique({ where: { id } });
  if (!season) throw new NotFoundError('Season');
  return toSeasonDto(season);
}

/**
 * Every season/pool that exists, newest first — for commissioner-facing UI
 * that needs to pick a pool rather than just resolve "the" active one (e.g.
 * generating invites for a specific pool). Not user-membership-scoped since
 * only a commissioner/admin can reach this.
 */
export async function listSeasons(): Promise<SeasonDto[]> {
  const seasons = await prisma.season.findMany({ orderBy: { createdAt: 'desc' } });
  return seasons.map(toSeasonDto);
}

/**
 * Every pool a user has joined, with their role in each — the non-admin
 * equivalent of `listSeasons`, for the Flutter pool switcher. Ordered
 * active-first, then upcoming, then completed (each newest-created first) —
 * explicit JS sort rather than an `orderBy` on `status`, since Postgres
 * enum ordering follows declaration order, not this priority (bit us once
 * already in `getActiveSeason`).
 */
export async function listMySeasons(userId: string): Promise<MySeasonDto[]> {
  const memberships = await prisma.seasonMembership.findMany({
    where: { userId },
    include: { season: true },
  });

  const statusPriority: Record<SeasonStatus, number> = { active: 0, upcoming: 1, completed: 2 };
  memberships.sort((a, b) => {
    const byStatus = statusPriority[a.season.status] - statusPriority[b.season.status];
    if (byStatus !== 0) return byStatus;
    return b.season.createdAt.getTime() - a.season.createdAt.getTime();
  });

  return memberships.map((m) => ({ ...toSeasonDto(m.season), myRole: m.role }));
}

/**
 * The season a given user should currently see/manage: the active one if
 * there is one, otherwise the most recently created upcoming season —
 * scoped to seasons the user has actually joined (`SeasonMembership`), since
 * a person can belong to more than one pool at once (e.g. a preseason test
 * pool and the main season). If they somehow belong to more than one
 * simultaneously-active-or-upcoming pool, this deterministically picks one;
 * there's no pool switcher yet, so treat that as a known limitation rather
 * than a resolved multi-pool UI.
 */
export async function getActiveSeason(userId: string): Promise<SeasonDto> {
  const membershipFilter = { memberships: { some: { userId } } };

  const active = await prisma.season.findFirst({
    where: { status: 'active', ...membershipFilter },
    orderBy: { createdAt: 'desc' },
  });
  if (active) return toSeasonDto(active);

  const upcoming = await prisma.season.findFirst({
    where: { status: 'upcoming', ...membershipFilter },
    orderBy: { createdAt: 'desc' },
  });
  if (upcoming) return toSeasonDto(upcoming);

  throw new NotFoundError('Active season');
}

export interface SeasonMemberDto {
  userId: string;
  name: string;
  email: string;
  role: PoolRole;
}

/**
 * A season's roster (name/email/role per member) — used by the commissioner
 * "enter picks for player" flow to pick a target player. Unlike
 * `GET /admin/users`, this is scoped to one season and reachable by that
 * season's commissioner, not just a global admin.
 */
export async function getSeasonMembers(seasonId: string): Promise<SeasonMemberDto[]> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const memberships = await prisma.seasonMembership.findMany({
    where: { seasonId },
    include: { user: { select: { id: true, name: true, email: true } } },
    orderBy: { user: { name: 'asc' } },
  });
  return memberships.map((m) => ({
    userId: m.user.id,
    name: m.user.name,
    email: m.user.email,
    role: m.role,
  }));
}

/**
 * Creates a shell account — a `User` row with just a name/email (no
 * password/Google login) — for a player with no account at all, enrolled in
 * `seasonId` so they immediately show up in the season roster/standings like
 * any other player. The commissioner then enters that player's picks against
 * this user's id via the normal pick-entry route. If the player later signs
 * up for real with the same email, `auth.service` claims this row in place
 * instead of creating a duplicate.
 */
export async function createShellMember(
  seasonId: string,
  input: { name: string; email: string },
): Promise<SeasonMemberDto> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) throw new ConflictError('An account with this email already exists');

  const member = await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: { name: input.name, email: input.email, isShellAccount: true },
    });
    await tx.seasonMembership.create({ data: { userId: user.id, seasonId } });
    return user;
  });

  return { userId: member.id, name: member.name, email: member.email, role: 'player' };
}

export async function listWeeks(seasonId: string): Promise<WeekSummaryDto[]> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const weeks = await prisma.week.findMany({
    where: { seasonId },
    orderBy: { weekNumber: 'asc' },
    include: { games: { select: { id: true } } },
  });
  return weeks.map(toWeekSummaryDto);
}

export async function createSeason(input: {
  name: string;
  year: number;
  entryFee?: number;
  payout1stPct?: number;
  payout2ndPct?: number;
  payout3rdPct?: number;
  defaultWeeklyPot?: number;
}): Promise<SeasonDto> {
  const season = await prisma.season.create({
    data: {
      name: input.name,
      year: input.year,
      entryFee: input.entryFee ?? 0,
      payout1stPct: input.payout1stPct ?? 50,
      payout2ndPct: input.payout2ndPct ?? 30,
      payout3rdPct: input.payout3rdPct ?? 20,
      defaultWeeklyPot: input.defaultWeeklyPot ?? null,
    },
  });
  return toSeasonDto(season);
}

export async function updateSeason(
  seasonId: string,
  input: Partial<{
    name: string;
    status: SeasonStatus;
    entryFee: number;
    payout1stPct: number;
    payout2ndPct: number;
    payout3rdPct: number;
    defaultWeeklyPot: number | null;
  }>,
): Promise<SeasonDto> {
  const existing = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!existing) throw new NotFoundError('Season');

  const season = await prisma.season.update({ where: { id: seasonId }, data: input });
  return toSeasonDto(season);
}
