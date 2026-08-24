import { PrismaClient, Sport } from '@prisma/client';
import { getTeams } from '../lib/espn-client';

const prisma = new PrismaClient();

async function seedSport(sport: Sport, espnSport: 'college' | 'nfl' | 'mlb') {
  const teams = await getTeams(espnSport);
  console.log(`Fetched ${teams.length} ${sport} teams from ESPN`);

  for (const team of teams) {
    await prisma.team.upsert({
      where: { sport_espnId: { sport, espnId: team.espnId } },
      update: {
        name: team.name,
        abbreviation: team.abbreviation,
        logoUrl: team.logoUrl,
        conference: team.conference,
      },
      create: {
        espnId: team.espnId,
        name: team.name,
        abbreviation: team.abbreviation,
        logoUrl: team.logoUrl,
        conference: team.conference,
        sport,
      },
    });
  }
}

async function main() {
  console.log('Seeding teams from ESPN...');
  await seedSport(Sport.nfl, 'nfl');
  await seedSport(Sport.college, 'college');
  await seedSport(Sport.mlb, 'mlb');
  console.log('Team seeding complete.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
