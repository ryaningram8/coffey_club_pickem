-- CreateEnum
CREATE TYPE "PoolRole" AS ENUM ('player', 'commissioner');

-- AlterTable: User.role (global Role enum) -> User.isAdmin (global boolean)
ALTER TABLE "User" ADD COLUMN "isAdmin" BOOLEAN NOT NULL DEFAULT false;
UPDATE "User" SET "isAdmin" = true WHERE "role" = 'admin';
ALTER TABLE "User" DROP COLUMN "role";
DROP TYPE "Role";

-- AlterTable: SeasonMembership gains a per-pool role, defaulting existing rows to player
ALTER TABLE "SeasonMembership" ADD COLUMN "role" "PoolRole" NOT NULL DEFAULT 'player';
