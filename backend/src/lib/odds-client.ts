import axios from 'axios';
import { logger } from './logger';

const BASE_URL = 'https://api.the-odds-api.com/v4/sports';

export type OddsSport = 'college' | 'nfl';

const SPORT_KEY: Record<OddsSport, string> = {
  college: 'americanfootball_ncaaf',
  nfl: 'americanfootball_nfl',
};

export interface GameOdds {
  homeTeamName: string;
  awayTeamName: string;
  commenceTime: string; // ISO
  spread: number | null; // home team spread; negative = home favored
  overUnder: number | null;
}

interface OddsApiEvent {
  home_team: string;
  away_team: string;
  commence_time: string;
  bookmakers?: Array<{
    markets?: Array<{
      key: 'spreads' | 'totals';
      outcomes?: Array<{ name: string; point?: number }>;
    }>;
  }>;
}

/**
 * Fetches current spreads + over/under totals for a sport from The Odds API.
 * Returns an empty list (rather than throwing) when no API key is configured
 * or the request fails — spreads/O-U are a display nicety, not a hard
 * dependency for picking winners.
 */
export async function getOdds(sport: OddsSport): Promise<GameOdds[]> {
  const apiKey = process.env.THE_ODDS_API_KEY;
  if (!apiKey) {
    logger.warn('THE_ODDS_API_KEY not set — skipping odds fetch');
    return [];
  }

  try {
    const { data } = await axios.get<OddsApiEvent[]>(
      `${BASE_URL}/${SPORT_KEY[sport]}/odds`,
      {
        params: {
          apiKey,
          regions: 'us',
          markets: 'spreads,totals',
          oddsFormat: 'american',
        },
      },
    );

    return data.map((event) => {
      const bookmaker = event.bookmakers?.[0];
      const spreadMarket = bookmaker?.markets?.find((m) => m.key === 'spreads');
      const totalsMarket = bookmaker?.markets?.find((m) => m.key === 'totals');
      const homeSpread = spreadMarket?.outcomes?.find(
        (o) => o.name === event.home_team,
      );

      return {
        homeTeamName: event.home_team,
        awayTeamName: event.away_team,
        commenceTime: event.commence_time,
        spread: homeSpread?.point ?? null,
        overUnder: totalsMarket?.outcomes?.[0]?.point ?? null,
      };
    });
  } catch (err) {
    logger.error({ err, sport }, 'The Odds API fetch failed');
    return [];
  }
}
