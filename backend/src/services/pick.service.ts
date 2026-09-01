import { prisma } from '../lib/prisma';
import { ForbiddenError, NotFoundError, ValidationError } from '../lib/errors';

export interface PickDto {
  gameId: string;
  pickedTeamId: string;
  tiebreakerGuess?: number | null;
}

export async function getUserPicks(weekId: string, userId: string): Promise<PickDto[]> {
  const picks = await prisma.pick.findMany({ where: { weekId, userId } });
  return picks.map((p) => ({
    gameId: p.gameId,
    pickedTeamId: p.pickedTeamId,
    tiebreakerGuess: p.tiebreakerGuess,
  }));
}

/**
 * Validates that every tiebreaker game in the week has a corresponding pick
 * carrying a non-negative integer guess. Shared by both submission paths so
 * the requirement can't be bypassed via the commissioner catch-up route.
 */
function assertTiebreakerGuesses(games: { id: string; isTiebreaker: boolean }[], picks: PickDto[]) {
  const picksByGameId = new Map(picks.map((p) => [p.gameId, p]));
  for (const game of games) {
    if (!game.isTiebreaker) continue;
    const guess = picksByGameId.get(game.id)?.tiebreakerGuess;
    if (typeof guess !== 'number' || !Number.isInteger(guess) || guess < 0) {
      throw new ValidationError(`A combined-score guess is required for tiebreaker game ${game.id}`);
    }
  }
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

  const membership = await prisma.seasonMembership.findUnique({
    where: { userId_seasonId: { userId, seasonId: week.seasonId } },
  });
  if (!membership) throw new ForbiddenError('You are not a member of this pool');

  const gamesById = new Map(week.games.map((g) => [g.id, g]));
  for (const pick of picks) {
    const game = gamesById.get(pick.gameId);
    if (!game) throw new ValidationError(`Game ${pick.gameId} is not part of this week`);
    if (pick.pickedTeamId !== game.homeTeamId && pick.pickedTeamId !== game.awayTeamId) {
      throw new ValidationError(`Invalid team selection for game ${pick.gameId}`);
    }
  }
  assertTiebreakerGuesses(week.games, picks);

  await prisma.$transaction(
    picks.map((pick) => {
      const game = gamesById.get(pick.gameId)!;
      const tiebreakerGuess = game.isTiebreaker ? (pick.tiebreakerGuess ?? null) : null;
      return prisma.pick.upsert({
        where: { userId_gameId: { userId, gameId: pick.gameId } },
        update: { pickedTeamId: pick.pickedTeamId, tiebreakerGuess },
        create: { userId, gameId: pick.gameId, weekId, pickedTeamId: pick.pickedTeamId, tiebreakerGuess },
      });
    }),
  );

  return getUserPicks(weekId, userId);
}

/**
 * Commissioner-entered picks on behalf of another player (paper pick sheet
 * catch-up). Skips the pick-deadline and week-status checks `submitPicks`
 * enforces — the commissioner may be transcribing a physical sheet after
 * the week has locked — but keeps every structural check: the target user
 * must be a member of the week's season, every game must belong to the
 * week, and every pick must be one of that game's two actual teams. Upserts
 * the same way `submitPicks` does, so re-entering/correcting a player's
 * picks overwrites rather than duplicating.
 */
export async function submitPicksForPlayer(
  weekId: string,
  targetUserId: string,
  picks: PickDto[],
): Promise<PickDto[]> {
  const week = await prisma.week.findUnique({
    where: { id: weekId },
    include: { games: true },
  });
  if (!week) throw new NotFoundError('Week');

  const membership = await prisma.seasonMembership.findUnique({
    where: { userId_seasonId: { userId: targetUserId, seasonId: week.seasonId } },
  });
  if (!membership) throw new ValidationError('This user is not a member of this pool');

  const gamesById = new Map(week.games.map((g) => [g.id, g]));
  for (const pick of picks) {
    const game = gamesById.get(pick.gameId);
    if (!game) throw new ValidationError(`Game ${pick.gameId} is not part of this week`);
    if (pick.pickedTeamId !== game.homeTeamId && pick.pickedTeamId !== game.awayTeamId) {
      throw new ValidationError(`Invalid team selection for game ${pick.gameId}`);
    }
  }
  // Unlike submitPicks, a guess is not required here — the paper pick sheet
  // this route transcribes from has no tiebreaker section, so the
  // commissioner may have nothing to enter for it.

  await prisma.$transaction(
    picks.map((pick) => {
      const game = gamesById.get(pick.gameId)!;
      const tiebreakerGuess = game.isTiebreaker ? (pick.tiebreakerGuess ?? null) : null;
      return prisma.pick.upsert({
        where: { userId_gameId: { userId: targetUserId, gameId: pick.gameId } },
        update: { pickedTeamId: pick.pickedTeamId, tiebreakerGuess },
        create: {
          userId: targetUserId,
          gameId: pick.gameId,
          weekId,
          pickedTeamId: pick.pickedTeamId,
          tiebreakerGuess,
        },
      });
    }),
  );

  return getUserPicks(weekId, targetUserId);
}
