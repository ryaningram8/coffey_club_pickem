-- DropIndex
DROP INDEX "Team_espnId_key";

-- CreateIndex
CREATE UNIQUE INDEX "Team_sport_espnId_key" ON "Team"("sport", "espnId");
