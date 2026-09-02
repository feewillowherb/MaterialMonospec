/**
 * experimental — verify UrbanManagement SQLite schema for AccessCode rename migrate graph.
 * Usage:
 *   node verify-schema.mjs --db <path> --mode pre|post --out <json> [--expected-migration <id>]
 */
import { DatabaseSync } from 'node:sqlite';
import { existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

function arg(name, fallback = undefined) {
  const i = process.argv.indexOf(name);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}

const dbPath = arg('--db');
const mode = arg('--mode', 'post');
const outPath = arg('--out');
const expectedMigration = arg(
  '--expected-migration',
  '20260902100000_RenameEntityBuildLicenseNoToAccessCode',
);

if (!dbPath || !outPath) {
  console.error(
    'Usage: node verify-schema.mjs --db <path> --mode pre|post --out <json> [--expected-migration <id>]',
  );
  process.exit(2);
}
if (!existsSync(dbPath)) {
  console.error(`DB not found: ${dbPath}`);
  process.exit(1);
}

const TARGET_TABLES = [
  'UrbanWeighingRecords',
  'UrbanPassageRecords',
  'GovSyncData',
  'GovProjects',
];

const db = new DatabaseSync(dbPath, { readOnly: true });

function tableExists(name) {
  const row = db
    .prepare(
      "SELECT 1 AS ok FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
    )
    .get(name);
  return Boolean(row);
}

function inspectTable(name) {
  if (!tableExists(name)) {
    return {
      exists: false,
      columns: [],
      hasBuildLicenseNo: false,
      hasAccessCode: false,
      rowCount: null,
    };
  }
  const cols = db.prepare(`PRAGMA table_info("${name}")`).all().map((c) => c.name);
  const rowCount = db.prepare(`SELECT COUNT(*) AS n FROM "${name}"`).get().n;
  return {
    exists: true,
    columns: cols,
    hasBuildLicenseNo: cols.includes('BuildLicenseNo'),
    hasAccessCode: cols.includes('AccessCode'),
    rowCount,
  };
}

const tables = {};
for (const t of TARGET_TABLES) {
  tables[t] = inspectTable(t);
}

let migrations = [];
if (tableExists('__EFMigrationsHistory')) {
  migrations = db
    .prepare('SELECT MigrationId FROM __EFMigrationsHistory ORDER BY MigrationId')
    .all()
    .map((r) => r.MigrationId);
}

const allTables = db
  .prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
  .all()
  .map((r) => r.name);

const result = {
  mode,
  dbPath,
  inspectedAt: new Date().toISOString(),
  tables,
  migrations,
  migrationCount: migrations.length,
  allTables,
  checks: {},
};

if (mode === 'pre') {
  result.checks = {
    weighingHasBuildLicenseNo: tables.UrbanWeighingRecords.hasBuildLicenseNo === true,
    weighingLacksAccessCode: tables.UrbanWeighingRecords.hasAccessCode === false,
    govSyncHasBuildLicenseNo: tables.GovSyncData.exists
      ? tables.GovSyncData.hasBuildLicenseNo === true
      : null,
    passageMissingOrLegacy: !tables.UrbanPassageRecords.exists
      || tables.UrbanPassageRecords.hasBuildLicenseNo === true,
  };
} else {
  const renameApplied = migrations.includes(expectedMigration);
  const weighingOk =
    tables.UrbanWeighingRecords.exists &&
    tables.UrbanWeighingRecords.hasAccessCode &&
    !tables.UrbanWeighingRecords.hasBuildLicenseNo;
  const passageOk =
    tables.UrbanPassageRecords.exists &&
    tables.UrbanPassageRecords.hasAccessCode &&
    !tables.UrbanPassageRecords.hasBuildLicenseNo;
  const govSyncOk =
    tables.GovSyncData.exists &&
    tables.GovSyncData.hasAccessCode &&
    !tables.GovSyncData.hasBuildLicenseNo;

  result.checks = {
    expectedMigration,
    renameMigrationApplied: renameApplied,
    weighingAccessCodeOnly: weighingOk,
    passageAccessCodeOnly: passageOk,
    govSyncAccessCodeOnly: govSyncOk,
    allTargetAccessCodeOnly: weighingOk && passageOk && govSyncOk,
  };
  result.ok =
    renameApplied && weighingOk && passageOk && govSyncOk;
}

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
console.log(JSON.stringify({ mode, outPath, ok: result.ok ?? true, migrationCount: result.migrationCount }, null, 2));
process.exit(mode === 'post' && result.ok === false ? 1 : 0);
