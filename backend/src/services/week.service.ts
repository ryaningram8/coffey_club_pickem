import type { Game, Sport, Team, Week, WeekStatus, GameStatus } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { NotFoundError, ValidationError } from '../lib/errors';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface TeamDto {
  id: string;
  name: string;
  abbreviation: string;
  logoUrl: string | null;
  sport: Sport;
  conference: string | null;
}

export interface GameDto {
  id: string;
  weekId: string;
  sport: Sport;
  status: GameStatus;
  gameTime: string;
  homeTeam: TeamDto;
  awayTeam: TeamDto;
  homeScore: number | null;
  awayScore: number | null;
  winnerTeamId: string | null;
  spread: string | null;
  overUnder: string | null;
  displayOrder: number;
}

export interface WeekDto {
  id: string;
  seasonId: string;
  weekNumber: number;
  label: string;
  pickDeadline: string;
  status: WeekStatus;
  pot: string | null;
  games: GameDto[];
}

export interface WeekSummaryDto {
  id: string;
  seasonId: string;
  weekNumber: number;
  label: string;
  pickDeadline: string;
  status: WeekStatus;
  pot: string | null;
  gameCount: number;
}

export interface AssignGameTeamInput {
  espnId: string;
  name: string;
  abbreviation: string;
  logoUrl?: string | null;
}

export interface AssignGameInput {
  espnGameId: string;
  sport: Sport;
  gameTime: Date;
  homeTeam: AssignGameTeamInput;
  awayTeam: AssignGameTeamInput;
  spread?: number | null;
  overUnder?: number | null;
}

type GameWithTeams = Game & { homeTeam: Team; awayTeam: Team };
type WeekWithGames = Week & { games: GameWithTeams[] };

// ─── Mappers ──────────────────────────────────────────────────────────────────

function toTeamDto(team: Team): TeamDto {
  return {
    id: team.id,
    name: team.name,
    abbreviation: team.abbreviation,
    logoUrl: team.logoUrl,
    sport: team.sport,
    conference: team.conference,
  };
}

function toGameDto(game: GameWithTeams): GameDto {
  return {
    id: game.id,
    weekId: game.weekId,
    sport: game.sport,
    status: game.status,
    gameTime: game.gameTime.toISOString(),
    homeTeam: toTeamDto(game.homeTeam),
    awayTeam: toTeamDto(game.awayTeam),
    homeScore: game.homeScore,
    awayScore: game.awayScore,
    winnerTeamId: game.winnerTeamId,
    spread: game.spread?.toString() ?? null,
    overUnder: game.overUnder?.toString() ?? null,
    displayOrder: game.displayOrder,
  };
}

function toWeekDto(week: WeekWithGames): WeekDto {
  return {
    id: week.id,
    seasonId: week.seasonId,
    weekNumber: week.weekNumber,
    label: week.label,
    pickDeadline: week.pickDeadline.toISOString(),
    status: week.status,
    pot: week.pot?.toString() ?? null,
    games: week.games.map(toGameDto),
  };
}

export function toWeekSummaryDto(week: Week & { games: { id: string }[] }): WeekSummaryDto {
  return {
    id: week.id,
    seasonId: week.seasonId,
    weekNumber: week.weekNumber,
    label: week.label,
    pickDeadline: week.pickDeadline.toISOString(),
    status: week.status,
    pot: week.pot?.toString() ?? null,
    gameCount: week.games.length,
  };
}

const gamesInclude = {
  games: { include: { homeTeam: true, awayTeam: true }, orderBy: { displayOrder: 'asc' as const } },
};

// ─── Service functions ────────────────────────────────────────────────────────

export async function createWeek(
  seasonId: string,
  input: { weekNumber: number; label: string; pickDeadline: Date },
): Promise<WeekSummaryDto> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const week = await prisma.week.create({
    data: { seasonId, ...input, pot: season.defaultWeeklyPot },
    include: gamesInclude,
  });
  return toWeekSummaryDto(week);
}

export async function updateWeek(
  weekId: string,
  input: Partial<{ label: string; pickDeadline: Date; status: WeekStatus; pot: number | null }>,
): Promise<WeekDto> {
  const existing = await prisma.week.findUnique({ where: { id: weekId } });
  if (!existing) throw new NotFoundError('Week');

  const week = await prisma.week.update({
    where: { id: weekId },
    data: input,
    include: gamesInclude,
  });
  return toWeekDto(week);
}

export async function getWeekWithGames(weekId: string): Promise<WeekDto> {
  const week = await prisma.week.findUnique({ where: { id: weekId }, include: gamesInclude });
  if (!week) throw new NotFoundError('Week');
  return toWeekDto(week);
}

/**
 * The week a player should currently see: an in-progress or open week if
 * one exists, otherwise the nearest upcoming week. Throws 404 if neither
 * exists (off-season / no weeks created yet) — callers treat that as an
 * empty state, not a hard error.
 */
export async function getCurrentWeek(): Promise<WeekDto> {
  const active = await prisma.week.findFirst({
    where: { status: { in: ['picks_open', 'locked', 'in_progress'] } },
    orderBy: { pickDeadline: 'asc' },
    include: gamesInclude,
  });
  if (active) return toWeekDto(active);

  const upcoming = await prisma.week.findFirst({
    where: { status: 'upcoming' },
    orderBy: { pickDeadline: 'asc' },
    include: gamesInclude,
  });
  if (upcoming) return toWeekDto(upcoming);

  throw new NotFoundError('Active week');
}

/**
 * Assigns candidate games (from GET /games/available) to a week. Each game
 * carries its own team details (name/abbreviation/logo), so teams are
 * upserted inline rather than requiring a separate seeding step first —
 * that avoids hard-failing on legitimate games ESPN's FBS-only team list
 * doesn't cover (e.g. an FBS team's scoreboard game against a smaller FCS
 * opponent). Games are upserted by `espnGameId` so re-submitting the same
 * game (e.g. to update its time) doesn't create a duplicate, and so
 * commissioners can incrementally add/replace games before the deadline.
 * The week flips from `upcoming` to `picks_open` on first publish only.
 */
export async function assignGames(weekId: string, games: AssignGameInput[]): Promise<WeekDto> {
  const week = await prisma.week.findUnique({ where: { id: weekId } });
  if (!week) throw new NotFoundError('Week');
  if (week.status !== 'upcoming' && week.status !== 'picks_open') {
    throw new ValidationError('Games can only be assigned before the week is locked');
  }

  await prisma.$transaction(async (tx) => {
    const teamCache = new Map<string, Team>();

    async function resolveTeam(sport: Sport, input: AssignGameTeamInput): Promise<Team> {
      const key = `${sport}:${input.espnId}`;
      const cached = teamCache.get(key);
      if (cached) return cached;

      const team = await tx.team.upsert({
        where: { sport_espnId: { sport, espnId: input.espnId } },
        update: {
          name: input.name,
          abbreviation: input.abbreviation,
          logoUrl: input.logoUrl ?? null,
        },
        create: {
          sport,
          espnId: input.espnId,
          name: input.name,
          abbreviation: input.abbreviation,
          logoUrl: input.logoUrl ?? null,
        },
      });
      teamCache.set(key, team);
      return team;
    }

    for (const [index, game] of games.entries()) {
      const homeTeam = await resolveTeam(game.sport, game.homeTeam);
      const awayTeam = await resolveTeam(game.sport, game.awayTeam);
      await tx.game.upsert({
        where: { espnGameId: game.espnGameId },
        update: {
          weekId,
          gameTime: game.gameTime,
          homeTeamId: homeTeam.id,
          awayTeamId: awayTeam.id,
          spread: game.spread ?? null,
          overUnder: game.overUnder ?? null,
          displayOrder: index,
        },
        create: {
          weekId,
          sport: game.sport,
          espnGameId: game.espnGameId,
          gameTime: game.gameTime,
          homeTeamId: homeTeam.id,
          awayTeamId: awayTeam.id,
          spread: game.spread ?? null,
          overUnder: game.overUnder ?? null,
          displayOrder: index,
        },
      });
    }
    if (week.status === 'upcoming') {
      await tx.week.update({ where: { id: weekId }, data: { status: 'picks_open' } });
    }
  });

  return getWeekWithGames(weekId);
}

async function getGameOrThrow(gameId: string) {
  const game = await prisma.game.findUnique({ where: { id: gameId }, include: { week: true } });
  if (!game) throw new NotFoundError('Game');
  return game;
}

function assertBeforeDeadline(week: Week) {
  if (week.pickDeadline <= new Date()) {
    throw new ValidationError('Cannot modify games after the pick deadline has passed');
  }
}

export async function updateGame(
  gameId: string,
  input: Partial<{
    gameTime: Date;
    spread: number | null;
    overUnder: number | null;
    status: GameStatus;
    displayOrder: number;
  }>,
): Promise<GameDto> {
  const game = await getGameOrThrow(gameId);
  assertBeforeDeadline(game.week);

  const updated = await prisma.game.update({
    where: { id: gameId },
    data: input,
    include: { homeTeam: true, awayTeam: true },
  });
  return toGameDto(updated);
}

export async function deleteGame(gameId: string): Promise<void> {
  const game = await getGameOrThrow(gameId);
  assertBeforeDeadline(game.week);
  await prisma.game.delete({ where: { id: gameId } });
}
