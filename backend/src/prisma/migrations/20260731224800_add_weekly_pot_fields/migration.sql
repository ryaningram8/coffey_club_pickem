-- AlterTable
ALTER TABLE "Season" ADD COLUMN     "defaultWeeklyPot" DECIMAL(10,2);

-- AlterTable
ALTER TABLE "Week" ADD COLUMN     "pot" DECIMAL(10,2);
