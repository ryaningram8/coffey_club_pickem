-- DropIndex
DROP INDEX "Game_espnGameId_key";

-- CreateIndex
CREATE UNIQUE INDEX "Game_weekId_espnGameId_key" ON "Game"("weekId", "espnGameId");
