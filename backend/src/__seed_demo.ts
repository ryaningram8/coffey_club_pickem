/**
 * One-off demo data for manually verifying the Phase 3 Flutter screens in a
 * browser: a live-in-progress week (mixed game statuses) and a completed
 * week with real WeeklyResult/SeasonStanding rows. Not part of the app —
 * delete after use. Login: admin@coffeyclub.local / admin-change-me
 */
import bcrypt from 'bcrypt';
import { prisma } from './lib/prisma';
import { finalizeWeek } from './services/results.service';

async function main() {
  const season = await prisma.season.update({
    where: { id: 'seed-season-2025' },
    data: { status: 'active', payout1stPct: 50, payout2ndPct: 30, payout3rdPct: 20 },
  });

  const passwordHash = await bcrypt.hash('demo-player-1', 12);
  const players = await Promise.all(
    [
      { email: 'alice@coffeyclub.local', name: 'Alice', venmoHandle: 'alice-v' },
      { email: 'bob@coffeyclub.local', name: 'Bob', venmoHandle: 'bob-v' },
      { email: 'carol@coffeyclub.local', name: 'Carol', venmoHandle: null },
      { email: 'dave@coffeyclub.local', name: 'Dave', venmoHandle: 'dave-v' },
    ].map((p) =>
      prisma.user.upsert({
        where: { email: p.email },
        update: {},
        create: { ...p, passwordHash },
      }),
    ),
  );
  // admin is deliberately excluded — the admin account never participates in
  // picks for any pool, only players do.
  const allUsers = players;

  async function team(name: string, abbr: string, espnId: string) {
    return prisma.team.upsert({
      where: { sport_espnId: { sport: 'nfl', espnId } },
      update: {},
      create: { name, abbreviation: abbr, sport: 'nfl', espnId },
    });
  }

  const chiefs = await team('Kansas City Chiefs', 'KC', 'demo-kc');
  const bills = await team('Buffalo Bills', 'BUF', 'demo-buf');
  const niners = await team('San Francisco 49ers', 'SF', 'demo-sf');
  const cowboys = await team('Dallas Cowboys', 'DAL', 'demo-dal');
  const eagles = await team('Philadelphia Eagles', 'PHI', 'demo-phi');
  const giants = await team('New York Giants', 'NYG', 'demo-nyg');

  // ── Live-in-progress week ────────────────────────────────────────────────
  const liveWeek = await prisma.week.upsert({
    where: { id: 'demo-week-live' },
    update: { status: 'locked', pot: 100 },
    create: {
      id: 'demo-week-live',
      seasonId: season.id,
      weekNumber: 90,
      label: 'Demo Live Week',
      pickDeadline: new Date(Date.now() - 3600_000),
      status: 'locked',
      pot: 100,
    },
  });

  const g1 = await prisma.game.upsert({
    where: { weekId_espnGameId: { weekId: liveWeek.id, espnGameId: 'demo-g1' } },
    update: { status: 'final', homeScore: 24, awayScore: 20, winnerTeamId: chiefs.id },
    create: {
      weekId: liveWeek.id,
      sport: 'nfl',
      homeTeamId: chiefs.id,
      awayTeamId: bills.id,
      gameTime: new Date(Date.now() - 3 * 3600_000),
      status: 'final',
      homeScore: 24,
      awayScore: 20,
      winnerTeamId: chiefs.id,
      espnGameId: 'demo-g1',
      displayOrder: 0,
    },
  });
  const g2 = await prisma.game.upsert({
    where: { weekId_espnGameId: { weekId: liveWeek.id, espnGameId: 'demo-g2' } },
    update: { status: 'in_progress', homeScore: 10, awayScore: 14 },
    create: {
      weekId: liveWeek.id,
      sport: 'nfl',
      homeTeamId: niners.id,
      awayTeamId: cowboys.id,
      gameTime: new Date(Date.now() - 1 * 3600_000),
      status: 'in_progress',
      homeScore: 10,
      awayScore: 14,
      espnGameId: 'demo-g2',
      displayOrder: 1,
    },
  });
  const g3 = await prisma.game.upsert({
    where: { weekId_espnGameId: { weekId: liveWeek.id, espnGameId: 'demo-g3' } },
    update: { status: 'scheduled' },
    create: {
      weekId: liveWeek.id,
      sport: 'nfl',
      homeTeamId: eagles.id,
      awayTeamId: giants.id,
      gameTime: new Date(Date.now() + 3 * 3600_000),
      status: 'scheduled',
      espnGameId: 'demo-g3',
      displayOrder: 2,
    },
  });

  const livePickWinners = [chiefs.id, cowboys.id, eagles.id]; // g1, g2, g3 picks per user (varied below)
  for (const [i, user] of allUsers.entries()) {
    const picks: Array<[string, string]> = [
      [g1.id, i % 2 === 0 ? chiefs.id : bills.id],
      [g2.id, i % 3 === 0 ? niners.id : cowboys.id],
      [g3.id, eagles.id],
    ];
    for (const [gameId, pickedTeamId] of picks) {
      await prisma.pick.upsert({
        where: { userId_gameId: { userId: user.id, gameId } },
        update: { pickedTeamId },
        create: { userId: user.id, gameId, weekId: liveWeek.id, pickedTeamId },
      });
    }
  }
  // Score the one final game (g1) the same way ScoreSyncJob would.
  await prisma.pick.updateMany({ where: { gameId: g1.id }, data: { isCorrect: false } });
  await prisma.pick.updateMany({
    where: { gameId: g1.id, pickedTeamId: chiefs.id },
    data: { isCorrect: true },
  });
  void livePickWinners;

  // ── Completed week with real standings/payouts ──────────────────────────
  const doneWeek = await prisma.week.upsert({
    where: { id: 'demo-week-done' },
    update: { status: 'in_progress', pot: 100 },
    create: {
      id: 'demo-week-done',
      seasonId: season.id,
      weekNumber: 89,
      label: 'Demo Completed Week',
      pickDeadline: new Date(Date.now() - 7200_000),
      status: 'in_progress',
      pot: 100,
    },
  });
  const dg1 = await prisma.game.upsert({
    where: { weekId_espnGameId: { weekId: doneWeek.id, espnGameId: 'demo-dg1' } },
    update: { status: 'final', homeScore: 27, awayScore: 24, winnerTeamId: chiefs.id },
    create: {
      weekId: doneWeek.id,
      sport: 'nfl',
      homeTeamId: chiefs.id,
      awayTeamId: bills.id,
      gameTime: new Date(Date.now() - 24 * 3600_000),
      status: 'final',
      homeScore: 27,
      awayScore: 24,
      winnerTeamId: chiefs.id,
      espnGameId: 'demo-dg1',
      displayOrder: 0,
    },
  });
  const dg2 = await prisma.game.upsert({
    where: { weekId_espnGameId: { weekId: doneWeek.id, espnGameId: 'demo-dg2' } },
    update: { status: 'final', homeScore: 17, awayScore: 31, winnerTeamId: cowboys.id },
    create: {
      weekId: doneWeek.id,
      sport: 'nfl',
      homeTeamId: niners.id,
      awayTeamId: cowboys.id,
      gameTime: new Date(Date.now() - 24 * 3600_000),
      status: 'final',
      homeScore: 17,
      awayScore: 31,
      winnerTeamId: cowboys.id,
      espnGameId: 'demo-dg2',
      displayOrder: 1,
    },
  });

  // alice picks both winners (sole 1st), bob picks 1 of 2, carol/dave pick 0.
  const donePicks: Record<string, [string, string]> = {
    [players[0].id]: [chiefs.id, cowboys.id],
    [players[1].id]: [chiefs.id, niners.id],
    [players[2].id]: [bills.id, niners.id],
    [players[3].id]: [bills.id, niners.id],
  };
  for (const [userId, [dg1Pick, dg2Pick]] of Object.entries(donePicks)) {
    await prisma.pick.upsert({
      where: { userId_gameId: { userId, gameId: dg1.id } },
      update: { pickedTeamId: dg1Pick, isCorrect: dg1Pick === chiefs.id },
      create: { userId, gameId: dg1.id, weekId: doneWeek.id, pickedTeamId: dg1Pick, isCorrect: dg1Pick === chiefs.id },
    });
    await prisma.pick.upsert({
      where: { userId_gameId: { userId, gameId: dg2.id } },
      update: { pickedTeamId: dg2Pick, isCorrect: dg2Pick === cowboys.id },
      create: { userId, gameId: dg2.id, weekId: doneWeek.id, pickedTeamId: dg2Pick, isCorrect: dg2Pick === cowboys.id },
    });
  }

  await finalizeWeek(doneWeek.id);

  console.log('Demo data ready.');
  console.log('Live week id:', liveWeek.id);
  console.log('Completed week id:', doneWeek.id);
  console.log('Season id:', season.id);
  console.log('Login: admin@coffeyclub.local / admin-change-me (admin+commissioner view)');
  console.log('Or any of alice/bob/carol/dave @coffeyclub.local / demo-player-1 (player view)');
}

main()
  .catch((err) => {
    console.error('SEED FAILED', err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
