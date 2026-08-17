-- CreateTable
CREATE TABLE "SeasonMembership" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "seasonId" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SeasonMembership_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SeasonMembership_userId_seasonId_key" ON "SeasonMembership"("userId", "seasonId");

-- AddForeignKey
ALTER TABLE "SeasonMembership" ADD CONSTRAINT "SeasonMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonMembership" ADD CONSTRAINT "SeasonMembership_seasonId_fkey" FOREIGN KEY ("seasonId") REFERENCES "Season"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Backfill: before this migration there was no membership concept, so every
-- existing user implicitly had access to every existing season. Enroll them
-- all so nothing breaks for people already using the app.
INSERT INTO "SeasonMembership" ("id", "userId", "seasonId", "joinedAt")
SELECT gen_random_uuid(), u."id", s."id", CURRENT_TIMESTAMP
FROM "User" u
CROSS JOIN "Season" s
ON CONFLICT ("userId", "seasonId") DO NOTHING;
