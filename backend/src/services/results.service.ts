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
 * the next distinct score skips accordingly.
 *
 * Payout: week.pot is split across ranks 1/2/3 using the season's
 * payout1st/2nd/3rdPct. A tie for a payout rank uses "place absorption" —
 * tied players evenly split the combined pct of the ranks they occupy (e.g.
 * two players tied for 1st each get (payout1stPct + payout2ndPct) / 2,
 * pushing the next distinct player to 3rd). This is a placeholder pending a
 * tie-breaker pick, which hasn't been designed yet.
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

  const payoutByUserId = new Map<string, string>();
  if (pot > 0) {
    for (const [rank, members] of groups) {
      if (rank > 3) continue;
      let combinedPct = 0;
      for (let slot = rank; slot < rank + members.length && slot <= 3; slot++) {
        combinedPct += pctByRank[slot] ?? 0;
      }
      if (combinedPct === 0) continue;
      const perMember = (pot * combinedPct) / 100 / members.length;
      for (const m of members) payoutByUserId.set(m.userId, perMember.toFixed(2));
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
