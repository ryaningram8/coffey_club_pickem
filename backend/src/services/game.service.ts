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
  isNeutralSite: boolean;
  venueName: string | null;
  venueCity: string | null;
  venueCountry: string | null;
}

function normalize(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function namesMatch(a: string, b: string): boolean {
  const na = normalize(a);
  const nb = normalize(b);
  return na === nb || na.includes(nb) || nb.includes(na);
}

export interface DateRange {
  start: Date;
  end: Date;
}

const toEspnDate = (d: Date) => d.toISOString().slice(0, 10).replace(/-/g, '');

/**
 * Today through 8 days out, as ESPN's `dates=YYYYMMDD-YYYYMMDD` range param.
 * ESPN's scoreboard defaults to its own idea of "current week", which near a
 * week boundary can mean the slate that just finished rather than the
 * upcoming one — an explicit forward-looking range avoids that. Starting
 * from today (not tomorrow) keeps same-day games visible too. Used only when
 * the caller (commissioner) hasn't picked their own range — e.g. to line up
 * games for a week being set up further out.
 */
function defaultDateRange(days = 8): DateRange {
  const start = new Date();
  const end = new Date();
  end.setDate(end.getDate() + days);
  return { start, end };
}

async function getAvailableForSport(
  dbSport: Sport,
  dateRange: DateRange,
): Promise<AvailableGameDto[]> {
  const espnDates = `${toEspnDate(dateRange.start)}-${toEspnDate(dateRange.end)}`;
  const [games, odds] = await Promise.all([
    getScoreboardSafe(dbSport, { date: espnDates }),
    getOdds(dbSport),
  ]);

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
      isNeutralSite: game.isNeutralSite,
      venueName: game.venueName,
      venueCity: game.venueCity,
      venueCountry: game.venueCountry,
    };
  });
}

/**
 * Candidate games for a commissioner to choose from — not yet persisted.
 * Merges ESPN's current scoreboard with The Odds API's spread/O-U by
 * matching team names (best-effort; see odds-refresh.job.ts for the same
 * matching heuristic used post-publish).
 */
export async function getAvailableGames(
  sport?: Sport,
  dateRange?: DateRange,
): Promise<AvailableGameDto[]> {
  const sports: Sport[] = sport ? [sport] : ['college', 'nfl', 'mlb'];
  const range = dateRange ?? defaultDateRange();
  const results = await Promise.all(sports.map((s) => getAvailableForSport(s, range)));
  return results.flat();
}
