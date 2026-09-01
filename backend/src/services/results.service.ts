import type { Prisma } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { NotFoundError } from '../lib/errors';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface WeekStandingDto {
  userId: string;
  userName: string;
  venmoHandle: string | null;
  correctPicks: number;
  totalPicks: number;
  rank: number | null;
  payoutAmount: string | null;
  isPaid: boolean;
}

export interface SeasonStandingDto {
  userId: string;
  userName: string;
  totalCorrect: number;
  weeksPlayed: number;
  totalPayout: string;
}

export interface PickSummaryEntryDto {
  userId: string;
  userName: string;
  picks: Array<{ gameId: string; pickedTeamId: string; isCorrect: boolean | null }>;
}

export interface TiebreakerGameDto {
  gameId: string;
  homeTeamName: string;
  awayTeamName: string;
  actualCombinedScore: number | null;
}

export interface TiebreakerEntryDto {
  userId: string;
  userName: string;
  guesses: Array<{ gameId: string; guess: number | null }>;
  guessTotal: number | null;
  distance: number | null;
}

export interface WeekTiebreakerDto {
  games: TiebreakerGameDto[];
  entries: TiebreakerEntryDto[];
}

function toDecimalString(d: Prisma.Decimal | null): string | null {
  return d?.toString() ?? null;
}

// ─── Reads ────────────────────────────────────────────────────────────────────

export async function getWeekStandings(weekId: string): Promise<WeekStandingDto[]> {
  const week = await prisma.week.findUnique({ where: { id: weekId } });
  if (!week) throw new NotFoundError('Week');

  const results = await prisma.weeklyResult.findMany({
    where: { weekId },
    include: { user: { select: { id: true, name: true, venmoHandle: true } } },
    orderBy: [{ rank: 'asc' }, { correctPicks: 'desc' }],
  });
  return results.map((r) => ({
    userId: r.userId,
    userName: r.user.name,
    venmoHandle: r.user.venmoHandle,
    correctPicks: r.correctPicks,
    totalPicks: r.totalPicks,
    rank: r.rank,
    payoutAmount: toDecimalString(r.payoutAmount),
    isPaid: r.isPaid,
  }));
}

export async function getSeasonStandings(seasonId: string): Promise<SeasonStandingDto[]> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const standings = await prisma.seasonStanding.findMany({
    where: { seasonId },
    include: { user: { select: { id: true, name: true } } },
    orderBy: [{ totalCorrect: 'desc' }],
  });
  return standings.map((s) => ({
    userId: s.userId,
    userName: s.user.name,
    totalCorrect: s.totalCorrect,
    weeksPlayed: s.weeksPlayed,
    totalPayout: s.totalPayout.toString(),
  }));
}

export async function getPicksSummary(weekId: string): Promise<PickSummaryEntryDto[]> {
  const week = await prisma.week.findUnique({ where: { id: weekId } });
  if (!week) throw new NotFoundError('Week');

  const picks = await prisma.pick.findMany({
    where: { weekId },
    include: { user: { select: { id: true, name: true } } },
    orderBy: { user: { name: 'asc' } },
  });

  const byUser = new Map<string, PickSummaryEntryDto>();
  for (const pick of picks) {
    let entry = byUser.get(pick.userId);
    if (!entry) {
      entry = { userId: pick.userId, userName: pick.user.name, picks: [] };
      byUser.set(pick.userId, entry);
    }
    entry.picks.push({
      gameId: pick.gameId,
      pickedTeamId: pick.pickedTeamId,
      isCorrect: pick.isCorrect,
    });
  }
  return [...byUser.values()];
}

interface TiebreakerContext {
  games: Array<{
    id: string;
    homeTeamName: string;
    awayTeamName: string;
    homeScore: number | null;
    awayScore: number | null;
  }>;
  /** Sum of both games' combined scores — only set once both tiebreaker games are `final`. */
  actualCombinedTotal: number | null;
  /** userId -> gameId -> guess, present only where a Pick row exists for that game. */
  guessesByUser: Map<string, Map<string, number | null>>;
}

/**
 * Loads the week's designated tiebreaker games (at most 2, per
 * `setGameTiebreaker`) plus every submitted guess for them. Shared by
 * `getWeekTiebreaker` (player/standings-facing detail) and `finalizeWeek`
 * (payout ordering) so both use the same "both games final" resolution gate.
 */
async function getTiebreakerContext(weekId: string): Promise<TiebreakerContext> {
  const games = await prisma.game.findMany({
    where: { weekId, isTiebreaker: true },
    include: { homeTeam: { select: { name: true } }, awayTeam: { select: { name: true } } },
    orderBy: { displayOrder: 'asc' },
  });

  const actualCombinedTotal =
    games.length === 2 && games.every((g) => g.status === 'final' && g.homeScore != null && g.awayScore != null)
      ? games.reduce((sum, g) => sum + g.homeScore! + g.awayScore!, 0)
      : null;

  const guessesByUser = new Map<string, Map<string, number | null>>();
  if (games.length > 0) {
    const picks = await prisma.pick.findMany({
      where: { weekId, gameId: { in: games.map((g) => g.id) } },
      select: { userId: true, gameId: true, tiebreakerGuess: true },
    });
    for (const p of picks) {
      const entry = guessesByUser.get(p.userId) ?? new Map<string, number | null>();
      entry.set(p.gameId, p.tiebreakerGuess);
      guessesByUser.set(p.userId, entry);
    }
  }

  return {
    games: games.map((g) => ({
      id: g.id,
      homeTeamName: g.homeTeam.name,
      awayTeamName: g.awayTeam.name,
      homeScore: g.homeScore,
      awayScore: g.awayScore,
    })),
    actualCombinedTotal,
    guessesByUser,
  };
}

/** Sum of a user's guesses across every tiebreaker game, or null if any is missing. */
function guessTotalFor(context: TiebreakerContext, userId: string): number | null {
  const guesses = context.guessesByUser.get(userId);
  let total = 0;
  for (const game of context.games) {
    const guess = guesses?.get(game.id);
    if (guess == null) return null;
    total += guess;
  }
  return total;
}

/** Distance between a user's total guess and the actual combined score, or null if either is unresolved. */
function distanceFor(context: TiebreakerContext, userId: string): number | null {
  const total = guessTotalFor(context, userId);
  return total != null && context.actualCombinedTotal != null
    ? Math.abs(total - context.actualCombinedTotal)
    : null;
}

export async function getWeekTiebreaker(weekId: string): Promise<WeekTiebreakerDto> {
  const week = await prisma.week.findUnique({ where: { id: weekId } });
  if (!week) throw new NotFoundError('Week');

  const context = await getTiebreakerContext(weekId);
  if (context.games.length === 0) return { games: [], entries: [] };

  const participants = await prisma.pick.findMany({
    where: { weekId },
    distinct: ['userId'],
    select: { userId: true, user: { select: { name: true } } },
  });

  const entries: TiebreakerEntryDto[] = participants.map(({ userId, user }) => {
    const guessTotal = guessTotalFor(context, userId);
    const distance =
      guessTotal != null && context.actualCombinedTotal != null
        ? Math.abs(guessTotal - context.actualCombinedTotal)
        : null;
    return {
      userId,
      userName: user.name,
      guesses: context.games.map((g) => ({
        gameId: g.id,
        guess: context.guessesByUser.get(userId)?.get(g.id) ?? null,
      })),
      guessTotal,
      distance,
    };
  });

  return {
    games: context.games.map((g) => ({
      gameId: g.id,
      homeTeamName: g.homeTeamName,
      awayTeamName: g.awayTeamName,
      actualCombinedScore: g.homeScore != null && g.awayScore != null ? g.homeScore + g.awayScore : null,
    })),
    entries,
  };
}

export async function markPayout(
  weekId: string,
  userId: string,
  isPaid: boolean,
): Promise<WeekStandingDto> {
  const existing = await prisma.weeklyResult.findUnique({
    where: { userId_weekId: { userId, weekId } },
  });
  if (!existing) throw new NotFoundError('WeeklyResult');

  const updated = await prisma.weeklyResult.update({
    where: { userId_weekId: { userId, weekId } },
    data: { isPaid },
    include: { user: { select: { id: true, name: true, venmoHandle: true } } },
  });
  return {
    userId: updated.userId,
    userName: updated.user.name,
    venmoHandle: updated.user.venmoHandle,
    correctPicks: updated.correctPicks,
    totalPicks: updated.totalPicks,
    rank: updated.rank,
    payoutAmount: toDecimalString(updated.payoutAmount),
    isPaid: updated.isPaid,
  };
}

// ─── Finalization ─────────────────────────────────────────────────────────────

export async function isWeekAllGamesFinal(weekId: string): Promise<boolean> {
  const games = await prisma.game.findMany({ where: { weekId }, select: { status: true } });
  if (games.length === 0) return false;
  return games.every((g) => g.status === 'final' || g.status === 'cancelled');
}

/**
 * Computes and writes WeeklyResult rows for every user who submitted at
 * least one pick in the week, then rolls up SeasonStanding for the whole
 * season from scratch. Idempotent — recomputes fully each run, so it's safe
 * to call again (e.g. after a late score correction re-triggers it).
 *
 * Ranking: standard competition ranking (1, 2, 2, 4) — ties share a rank,
 * the next distinct score skips accordingly. Displayed rank is never split
 * apart by the tiebreaker — only payout order is.
 *
 * Payout: week.pot is split across ranks 1/2/3 using the season's
 * payout1st/2nd/3rdPct. A tie for a payout rank is resolved using the
 * week's tiebreaker games when possible: members are ordered by ascending
 * distance from their combined-score guess (summed across both tiebreaker
 * games) to the actual combined score, and each gets the exact rank slot's
 * pct rather than a share. Any remaining sub-tie (equal distance, or no
 * distance available for every member — no tiebreaker games set, one isn't
 * final yet, or a guess is missing) falls back to "place absorption": those
 * members evenly split the combined pct of the ranks they occupy.
 */
export async function finalizeWeek(weekId: string): Promise<void> {
  const week = await prisma.week.findUnique({ where: { id: weekId } });
  if (!week) throw new NotFoundError('Week');

  const season = await prisma.season.findUnique({ where: { id: week.seasonId } });
  if (!season) throw new NotFoundError('Season');

  const picks = await prisma.pick.findMany({ where: { weekId } });
  const byUser = new Map<string, { correct: number; total: number }>();
  for (const pick of picks) {
    const entry = byUser.get(pick.userId) ?? { correct: 0, total: 0 };
    entry.total += 1;
    if (pick.isCorrect) entry.correct += 1;
    byUser.set(pick.userId, entry);
  }

  const standings = [...byUser.entries()]
    .map(([userId, { correct, total }]) => ({ userId, correctPicks: correct, totalPicks: total }))
    .sort((a, b) => b.correctPicks - a.correctPicks);

  const ranked = standings.map((s, i) => ({
    ...s,
    rank: i === 0 || s.correctPicks !== standings[i - 1].correctPicks ? i + 1 : -1,
  }));
  for (let i = 1; i < ranked.length; i++) {
    if (ranked[i].rank === -1) ranked[i].rank = ranked[i - 1].rank;
  }

  const pctByRank: Record<number, number> = {
    1: Number(season.payout1stPct),
    2: Number(season.payout2ndPct),
    3: Number(season.payout3rdPct),
  };
  const pot = week.pot ? Number(week.pot) : 0;

  const groups = new Map<number, typeof ranked>();
  for (const r of ranked) {
    const group = groups.get(r.rank) ?? [];
    group.push(r);
    groups.set(r.rank, group);
  }

  function assignEvenSplit(members: typeof ranked, startRank: number) {
    let combinedPct = 0;
    for (let slot = startRank; slot < startRank + members.length && slot <= 3; slot++) {
      combinedPct += pctByRank[slot] ?? 0;
    }
    if (combinedPct === 0) return;
    const perMember = (pot * combinedPct) / 100 / members.length;
    for (const m of members) payoutByUserId.set(m.userId, perMember.toFixed(2));
  }

  const payoutByUserId = new Map<string, string>();
  if (pot > 0) {
    const tiebreakerContext = await getTiebreakerContext(weekId);
    for (const [rank, members] of groups) {
      if (rank > 3) continue;

      if (members.length > 1) {
        const distances = members.map((m) => distanceFor(tiebreakerContext, m.userId));
        if (distances.every((d) => d != null)) {
          const sorted = [...members].sort(
            (a, b) => distanceFor(tiebreakerContext, a.userId)! - distanceFor(tiebreakerContext, b.userId)!,
          );
          let offset = 0;
          while (offset < sorted.length) {
            const d = distanceFor(tiebreakerContext, sorted[offset].userId);
            let end = offset + 1;
            while (end < sorted.length && distanceFor(tiebreakerContext, sorted[end].userId) === d) end++;
            assignEvenSplit(sorted.slice(offset, end), rank + offset);
            offset = end;
          }
          continue;
        }
      }

      assignEvenSplit(members, rank);
    }
  }

  await prisma.$transaction([
    ...ranked.map((r) =>
      prisma.weeklyResult.upsert({
        where: { userId_weekId: { userId: r.userId, weekId } },
        update: {
          correctPicks: r.correctPicks,
          totalPicks: r.totalPicks,
          rank: r.rank,
          payoutAmount: payoutByUserId.get(r.userId) ?? null,
        },
        create: {
          userId: r.userId,
          weekId,
          correctPicks: r.correctPicks,
          totalPicks: r.totalPicks,
          rank: r.rank,
          payoutAmount: payoutByUserId.get(r.userId) ?? null,
        },
      }),
    ),
    prisma.week.update({ where: { id: weekId }, data: { status: 'completed' } }),
  ]);

  await rollUpSeasonStandings(week.seasonId);
}

async function rollUpSeasonStandings(seasonId: string): Promise<void> {
  const results = await prisma.weeklyResult.findMany({ where: { week: { seasonId } } });

  const byUser = new Map<string, { totalCorrect: number; weeksPlayed: number; totalPayout: number }>();
  for (const r of results) {
    const entry = byUser.get(r.userId) ?? { totalCorrect: 0, weeksPlayed: 0, totalPayout: 0 };
    entry.totalCorrect += r.correctPicks;
    entry.weeksPlayed += 1;
    entry.totalPayout += r.payoutAmount ? Number(r.payoutAmount) : 0;
    byUser.set(r.userId, entry);
  }

  await prisma.$transaction(
    [...byUser.entries()].map(([userId, s]) =>
      prisma.seasonStanding.upsert({
        where: { userId_seasonId: { userId, seasonId } },
        update: {
          totalCorrect: s.totalCorrect,
          weeksPlayed: s.weeksPlayed,
          totalPayout: s.totalPayout.toFixed(2),
        },
        create: {
          userId,
          seasonId,
          totalCorrect: s.totalCorrect,
          weeksPlayed: s.weeksPlayed,
          totalPayout: s.totalPayout.toFixed(2),
        },
      }),
    ),
  );
}
