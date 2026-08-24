import type { Sport } from '@prisma/client';
import { getScoreboardSafe } from '../lib/espn-client';
import { getOdds } from '../lib/odds-client';

export interface AvailableTeamDto {
  espnId: string;
  name: string;
  abbreviation: string;
  logoUrl: string | null;
}

export interface AvailableGameDto {
  espnGameId: string;
  sport: Sport;
  gameTime: string;
  homeTeam: AvailableTeamDto;
  awayTeam: AvailableTeamDto;
  spread: number | null;
  overUnder: number | null;
}

function normalize(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function namesMatch(a: string, b: string): boolean {
  const na = normalize(a);
  const nb = normalize(b);
  return na === nb || na.includes(nb) || nb.includes(na);
}

async function getAvailableForSport(dbSport: Sport): Promise<AvailableGameDto[]> {
  const [games, odds] = await Promise.all([getScoreboardSafe(dbSport), getOdds(dbSport)]);

  return games.map((game) => {
    const match = odds.find(
      (o) => namesMatch(game.homeTeam.name, o.homeTeamName) && namesMatch(game.awayTeam.name, o.awayTeamName),
    );
    return {
      espnGameId: game.espnGameId,
      sport: dbSport,
      gameTime: game.gameTime,
      homeTeam: {
        espnId: game.homeTeam.espnId,
        name: game.homeTeam.name,
        abbreviation: game.homeTeam.abbreviation,
        logoUrl: game.homeTeam.logoUrl,
      },
      awayTeam: {
        espnId: game.awayTeam.espnId,
        name: game.awayTeam.name,
        abbreviation: game.awayTeam.abbreviation,
        logoUrl: game.awayTeam.logoUrl,
      },
      spread: match?.spread ?? null,
      overUnder: match?.overUnder ?? null,
    };
  });
}

/**
 * Candidate games for a commissioner to choose from — not yet persisted.
 * Merges ESPN's current scoreboard with The Odds API's spread/O-U by
 * matching team names (best-effort; see odds-refresh.job.ts for the same
 * matching heuristic used post-publish).
 */
export async function getAvailableGames(sport?: Sport): Promise<AvailableGameDto[]> {
  const sports: Sport[] = sport ? [sport] : ['college', 'nfl', 'mlb'];
  const results = await Promise.all(sports.map(getAvailableForSport));
  return results.flat();
}
