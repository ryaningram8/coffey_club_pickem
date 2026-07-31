import type { Season, SeasonStatus } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { NotFoundError } from '../lib/errors';
import { toWeekSummaryDto, type WeekSummaryDto } from './week.service';

export interface SeasonDto {
  id: string;
  name: string;
  year: number;
  status: SeasonStatus;
  entryFee: string;
  payout1stPct: string;
  payout2ndPct: string;
  payout3rdPct: string;
}

function toSeasonDto(season: Season): SeasonDto {
  return {
    id: season.id,
    name: season.name,
    year: season.year,
    status: season.status,
    entryFee: season.entryFee.toString(),
    payout1stPct: season.payout1stPct.toString(),
    payout2ndPct: season.payout2ndPct.toString(),
    payout3rdPct: season.payout3rdPct.toString(),
  };
}

export async function getSeason(id: string): Promise<SeasonDto> {
  const season = await prisma.season.findUnique({ where: { id } });
  if (!season) throw new NotFoundError('Season');
  return toSeasonDto(season);
}

/**
 * The season a commissioner should currently manage: the active one if
 * there is one, otherwise the most recently created upcoming season.
 * Not part of the original spec, but needed for the commissioner dashboard
 * to have anything to point at — same reasoning as week.service's
 * getCurrentWeek().
 */
export async function getActiveSeason(): Promise<SeasonDto> {
  const season = await prisma.season.findFirst({
    where: { status: { in: ['active', 'upcoming'] } },
    orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
  });
  if (!season) throw new NotFoundError('Active season');
  return toSeasonDto(season);
}

export async function listWeeks(seasonId: string): Promise<WeekSummaryDto[]> {
  const season = await prisma.season.findUnique({ where: { id: seasonId } });
  if (!season) throw new NotFoundError('Season');

  const weeks = await prisma.week.findMany({
    where: { seasonId },
    orderBy: { weekNumber: 'asc' },
    include: { games: { select: { id: true } } },
  });
  return weeks.map(toWeekSummaryDto);
}

export async function createSeason(input: {
  name: string;
  year: number;
  entryFee?: number;
  payout1stPct?: number;
  payout2ndPct?: number;
  payout3rdPct?: number;
}): Promise<SeasonDto> {
  const season = await prisma.season.create({
    data: {
      name: input.name,
      year: input.year,
      entryFee: input.entryFee ?? 0,
      payout1stPct: input.payout1stPct ?? 50,
      payout2ndPct: input.payout2ndPct ?? 30,
      payout3rdPct: input.payout3rdPct ?? 20,
    },
  });
  return toSeasonDto(season);
}
