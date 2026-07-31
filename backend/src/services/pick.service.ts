import { prisma } from '../lib/prisma';
import { NotFoundError, ValidationError } from '../lib/errors';

export interface PickDto {
  gameId: string;
  pickedTeamId: string;
}

export async function getUserPicks(weekId: string, userId: string): Promise<PickDto[]> {
  const picks = await prisma.pick.findMany({ where: { weekId, userId } });
  return picks.map((p) => ({ gameId: p.gameId, pickedTeamId: p.pickedTeamId }));
}

/**
 * Submits or updates a player's picks for a week. Validates the week is
 * still open, every game belongs to the week, and every pick is one of that
 * game's two actual teams — then upserts on the existing
 * `@@unique([userId, gameId])` constraint so resubmitting before the
 * deadline just overwrites prior picks.
 */
export async function submitPicks(
  weekId: string,
  userId: string,
  picks: PickDto[],
): Promise<PickDto[]> {
  const week = await prisma.week.findUnique({
    where: { id: weekId },
    include: { games: true },
  });
  if (!week) throw new NotFoundError('Week');
  if (week.status !== 'picks_open') {
    throw new ValidationError('Picks are not open for this week');
  }
  if (week.pickDeadline <= new Date()) {
    throw new ValidationError('The pick deadline for this week has passed');
  }

  const gamesById = new Map(week.games.map((g) => [g.id, g]));
  for (const pick of picks) {
    const game = gamesById.get(pick.gameId);
    if (!game) throw new ValidationError(`Game ${pick.gameId} is not part of this week`);
    if (pick.pickedTeamId !== game.homeTeamId && pick.pickedTeamId !== game.awayTeamId) {
      throw new ValidationError(`Invalid team selection for game ${pick.gameId}`);
    }
  }

  await prisma.$transaction(
    picks.map((pick) =>
      prisma.pick.upsert({
        where: { userId_gameId: { userId, gameId: pick.gameId } },
        update: { pickedTeamId: pick.pickedTeamId },
        create: { userId, gameId: pick.gameId, weekId, pickedTeamId: pick.pickedTeamId },
      }),
    ),
  );

  return getUserPicks(weekId, userId);
}
