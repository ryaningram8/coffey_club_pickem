-- AlterTable
ALTER TABLE "User" ADD COLUMN     "fcmTokens" TEXT[] DEFAULT ARRAY[]::TEXT[];
