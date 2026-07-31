import type { Game, Sport } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { getScoreboardSafe, type EspnGame } from '../lib/espn-client';
import { isWeekAllGamesFinal } from '../services/results.service';
import { WeekCompleteJob } from './week-complete.job';
import { logger } from '../lib/logger';

const SPORTS: Sport[] = ['college', 'nfl'];

/**
 * Pulls live scores/status from ESPN for every non-final game and syncs
 * them to the DB, matching by `espnGameId`. On a game's first transition to
 * `final`, resolves the winner and scores every pick for that game (a tie
 * scores nobody correct). When that leaves every game in a week final or
 * cancelled, hands off to WeekCompleteJob to compute results.
 *
 * Idempotent — skips games whose status/score already match ESPN, and
 * re-running a completed sync is a no-op.
 */
export class ScoreSyncJob {
  async process(): Promise<{ updated: number; weeksFinalized: number }> {
    logger.info('ScoreSyncJob starting');
    let updated = 0;
    const touchedWeekIds = new Set<string>();

    for (const sport of SPORTS) {
      const games = await prisma.game.findMany({
        where: {
          sport,
          status: { in: ['scheduled', 'in_progress'] },
          espnGameId: { not: null },
        },
      });
      if (games.length === 0) continue;

      const scoreboard = await getScoreboardSafe(sport);
      const byEspnId = new Map(scoreboard.map((g) => [g.espnGameId, g]));

      for (const game of games) {
        const live = byEspnId.get(game.espnGameId!);
        if (!live) continue;
        if (
          live.status === game.status &&
          live.homeScore === game.homeScore &&
          live.awayScore === game.awayScore
        ) {
          continue;
        }

        await this.syncGame(game, live);
        touchedWeekIds.add(game.weekId);
        updated++;
      }
    }

    let weeksFinalized = 0;
    for (const weekId of touchedWeekIds) {
      if (await isWeekAllGamesFinal(weekId)) {
        await new WeekCompleteJob().process(weekId);
        weeksFinalized++;
      }
    }

    logger.info({ updated, weeksFinalized }, 'ScoreSyncJob complete');
    return { updated, weeksFinalized };
  }

  private async syncGame(game: Game, live: EspnGame): Promise<void> {
    const isFinal = live.status === 'final';
    const winnerTeamId =
      isFinal && live.homeScore != null && live.awayScore != null && live.homeScore !== live.awayScore
        ? live.homeScore > live.awayScore
          ? game.homeTeamId
          : game.awayTeamId
        : null;

    await prisma.$transaction(async (tx) => {
      await tx.game.update({
        where: { id: game.id },
        data: {
          status: live.status,
          homeScore: live.homeScore,
          awayScore: live.awayScore,
          winnerTeamId,
        },
      });

      if (isFinal) {
        await tx.pick.updateMany({ where: { gameId: game.id }, data: { isCorrect: false } });
        if (winnerTeamId) {
          await tx.pick.updateMany({
            where: { gameId: game.id, pickedTeamId: winnerTeamId },
            data: { isCorrect: true },
          });
        }
      }
    });
  }
}
