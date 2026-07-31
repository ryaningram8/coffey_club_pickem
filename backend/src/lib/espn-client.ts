import axios from 'axios';
import { logger } from './logger';

const BASE_URL = 'https://site.api.espn.com/apis/site/v2/sports/football';

export type EspnSport = 'college' | 'nfl';

const LEAGUE_PATH: Record<EspnSport, string> = {
  college: 'college-football',
  nfl: 'nfl',
};

export interface EspnTeam {
  espnId: string;
  name: string;
  abbreviation: string;
  logoUrl: string | null;
  conference: string | null;
}

export interface EspnGame {
  espnGameId: string;
  gameTime: string; // ISO
  homeTeam: EspnTeam;
  awayTeam: EspnTeam;
}

interface EspnScoreboardResponse {
  events?: Array<{
    id: string;
    date: string;
    competitions?: Array<{
      competitors?: Array<{
        homeAway: 'home' | 'away';
        team: {
          id: string;
          displayName: string;
          abbreviation: string;
          logos?: Array<{ href: string }>;
        };
      }>;
    }>;
  }>;
}

interface EspnTeamsResponse {
  sports?: Array<{
    leagues?: Array<{
      teams?: Array<{
        team: {
          id: string;
          displayName: string;
          abbreviation: string;
          logos?: Array<{ href: string }>;
          groups?: { parent?: { name?: string } };
        };
      }>;
    }>;
  }>;
}

function toEspnTeam(team: {
  id: string;
  displayName: string;
  abbreviation: string;
  logos?: Array<{ href: string }>;
  groups?: { parent?: { name?: string } };
}): EspnTeam {
  return {
    espnId: team.id,
    name: team.displayName,
    abbreviation: team.abbreviation,
    logoUrl: team.logos?.[0]?.href ?? null,
    conference: team.groups?.parent?.name ?? null,
  };
}

/**
 * Fetches the current scoreboard (schedule + live scores) for a sport.
 * College football is restricted to FBS (groups=80) to keep the game list relevant.
 */
export async function getScoreboard(
  sport: EspnSport,
  opts: { week?: number } = {},
): Promise<EspnGame[]> {
  const params: Record<string, string | number> = {};
  if (sport === 'college') params.groups = 80;
  if (opts.week) params.week = opts.week;

  const { data } = await axios.get<EspnScoreboardResponse>(
    `${BASE_URL}/${LEAGUE_PATH[sport]}/scoreboard`,
    { params },
  );

  const games: EspnGame[] = [];
  for (const event of data.events ?? []) {
    const competitors = event.competitions?.[0]?.competitors ?? [];
    const home = competitors.find((c) => c.homeAway === 'home');
    const away = competitors.find((c) => c.homeAway === 'away');
    if (!home || !away) continue;

    games.push({
      espnGameId: event.id,
      gameTime: event.date,
      homeTeam: toEspnTeam(home.team),
      awayTeam: toEspnTeam(away.team),
    });
  }
  return games;
}

/**
 * Fetches all teams for a sport. College football uses a high limit since
 * the default page size (~25) would otherwise miss most FBS teams.
 */
export async function getTeams(sport: EspnSport): Promise<EspnTeam[]> {
  const params: Record<string, string | number> = { limit: 200 };
  if (sport === 'college') params.groups = 80;

  const { data } = await axios.get<EspnTeamsResponse>(
    `${BASE_URL}/${LEAGUE_PATH[sport]}/teams`,
    { params },
  );

  const entries = data.sports?.[0]?.leagues?.[0]?.teams ?? [];
  return entries.map((entry) => toEspnTeam(entry.team));
}

export async function getScoreboardSafe(
  sport: EspnSport,
  opts: { week?: number } = {},
): Promise<EspnGame[]> {
  try {
    return await getScoreboard(sport, opts);
  } catch (err) {
    logger.error({ err, sport }, 'ESPN scoreboard fetch failed');
    return [];
  }
}
