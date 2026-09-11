import { DatabaseSync } from 'node:sqlite';
import { existsSync } from 'node:fs';

const dbPath = process.argv[2];
if (!dbPath || !existsSync(dbPath)) {
  console.error('Usage: node apply-urban-migration-once.mjs <MaterialClient.db>');
  process.exit(1);
}

const db = new DatabaseSync(dbPath);
const cols = db.prepare('PRAGMA table_info("UrbanPassageRecords")').all().map((r) => r.name);
console.log('Before:', cols.join(', '));

if (!cols.includes('SyncStatus')) {
  db.exec('ALTER TABLE "UrbanPassageRecords" ADD COLUMN "SyncStatus" INTEGER NOT NULL DEFAULT 0;');
}
if (!cols.includes('RetryCount')) {
  db.exec('ALTER TABLE "UrbanPassageRecords" ADD COLUMN "RetryCount" INTEGER NOT NULL DEFAULT 0;');
}
if (!cols.includes('LastErrorTime')) {
  db.exec('ALTER TABLE "UrbanPassageRecords" ADD COLUMN "LastErrorTime" TEXT NULL;');
}
if (!cols.includes('SubmitMachineCode')) {
  db.exec('ALTER TABLE "UrbanPassageRecords" ADD COLUMN "SubmitMachineCode" TEXT NULL;');
}
if (!cols.includes('UploadedAt')) {
  db.exec('ALTER TABLE "UrbanPassageRecords" ADD COLUMN "UploadedAt" TEXT NULL;');
}
db.exec('CREATE INDEX IF NOT EXISTS "IX_UrbanPassageRecords_SyncStatus" ON "UrbanPassageRecords" ("SyncStatus");');

const extCols = db.prepare('PRAGMA table_info("UrbanWeighingExtensions")').all().map((r) => r.name);
if (!extCols.includes('UrbanInOutType')) {
  db.exec('ALTER TABLE "UrbanWeighingExtensions" ADD COLUMN "UrbanInOutType" INTEGER NULL;');
}

const after = db.prepare('PRAGMA table_info("UrbanPassageRecords")').all().map((r) => r.name);
console.log('After:', after.join(', '));
