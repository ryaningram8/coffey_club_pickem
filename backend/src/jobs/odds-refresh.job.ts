import type { Sport } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { getOdds, type OddsSport } from '../lib/odds-client';
import { logger } from '../lib/logger';

function normalize(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '');
}

/**
 * ESPN and The Odds API don't share team IDs, so games are matched by
 * normalized name (exact match, or one name containing the other — e.g.
 * "Ohio State Buckeyes" vs "Ohio State"). Best-effort; unmatched games
 * simply keep their existing spread/O-U until the next run.
 */
function namesMatch(teamName: string, oddsName: string): boolean {
  const a = normalize(teamName);
  const b = normalize(oddsName);
  return a === b || a.includes(b) || b.includes(a);
}

const SPORTS: Array<{ dbSport: Sport; oddsSport: OddsSport }> = [
  { dbSport: 'college', oddsSport: 'college' },
  { dbSport: 'nfl', oddsSport: 'nfl' },
  { dbSport: 'mlb', oddsSport: 'mlb' },
];

/**
 * Refreshes spread/over-under on games that haven't been played yet.
 * Idempotent — safe to run repeatedly, only ever overwrites with the
 * latest odds snapshot.
 */
export class OddsRefreshJob {
  async process(): Promise<{ updated: number }> {
    logger.info('OddsRefreshJob starting');
    let updated = 0;

    for (const { dbSport, oddsSport } of SPORTS) {
      const odds = await getOdds(oddsSport);
      if (odds.length === 0) continue;

      const games = await prisma.game.findMany({
        where: {
          sport: dbSport,
          status: { in: ['scheduled', 'in_progress'] },
          week: { status: { not: 'completed' } },
        },
        include: { homeTeam: true, awayTeam: true },
      });

      for (const game of games) {
        const match = odds.find(
          (o) =>
            namesMatch(game.homeTeam.name, o.homeTeamName) &&
            namesMatch(game.awayTeam.name, o.awayTeamName),
        );
        if (!match) continue;

        await prisma.game.update({
          where: { id: game.id },
          data: { spread: match.spread, overUnder: match.overUnder },
        });
        updated++;
      }
    }

    logger.info({ updated }, 'OddsRefreshJob complete');
    return { updated };
  }
}
