-- AlterTable
ALTER TABLE "Game" ADD COLUMN     "isTiebreaker" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "Pick" ADD COLUMN     "tiebreakerGuess" INTEGER;
