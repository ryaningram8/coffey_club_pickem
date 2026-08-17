import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Create admin user
  const adminPassword = await bcrypt.hash('admin-change-me', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@coffeyclub.local' },
    update: {},
    create: {
      email: 'admin@coffeyclub.local',
      name: 'Admin',
      passwordHash: adminPassword,
      isAdmin: true,
    },
  });

  console.log(`Admin user: ${admin.email}`);

  // Create a sample season
  const season = await prisma.season.upsert({
    where: { id: 'seed-season-2025' },
    update: {},
    create: {
      id: 'seed-season-2025',
      name: '2025 Season',
      year: 2025,
      status: 'upcoming',
      entryFee: 50,
    },
  });

  console.log(`Season: ${season.name}`);

  // Create a sample invite code
  await prisma.invitation.upsert({
    where: { code: 'COFFEY2025' },
    update: {},
    create: {
      code: 'COFFEY2025',
      seasonId: season.id,
      createdBy: admin.id,
    },
  });

  console.log('Sample invite code: COFFEY2025');
  console.log('Seeding complete.');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
