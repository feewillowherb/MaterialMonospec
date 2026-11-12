/**
 * Experimental probe. Node.js cook for a copied MaterialClient SQLite snapshot.
 * Reads product migration SQL and extension constants. Does not write the source file.
 */
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { backup, DatabaseSync } from "node:sqlite";

type ScalarMap = Record<string, string>;

type IdRow = { Id: number | bigint };

type ExtraRow = { Id: number | bigint; ExtraProperties: string | null; IsDeleted: number | bigint };

const SolidWasteMode = 1;

function arg(name: string): string {
  const index = process.argv.indexOf(name);
  const value = index >= 0 ? process.argv[index + 1] : undefined;
  if (!value) {
    throw new Error(`Missing argument ${name}`);
  }
  return value;
}

function yamlScalars(text: string): ScalarMap {
  const values: ScalarMap = {};
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z0-9_]+)\s*:\s*(.*?)\s*$/);
    if (!match) continue;
    let value = match[2].trim();
    if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    if (value.startsWith("'") && value.endsWith("'")) value = value.slice(1, -1);
    values[match[1]] = value;
  }
  return values;
}

function repoPath(repoRoot: string, relativePath: string): string {
  return resolve(repoRoot, relativePath);
}

function readConstString(source: string, name: string): string {
  const match = source.match(new RegExp(`const string ${name} = "([^"]*)";`));
  if (!match) throw new Error(`Missing string const ${name}`);
  return match[1];
}

function readConstInt(source: string, name: string): number {
  const match = source.match(new RegExp(`const int ${name} = (\\d+);`));
  if (!match) throw new Error(`Missing int const ${name}`);
  return Number(match[1]);
}

function readMigrationSql(source: string): string {
  const match = source.match(/migrationBuilder\.Sql\("""([\s\S]*?)"""\)/);
  if (!match) throw new Error("Product migration SQL was not found");
  return match[1].trim();
}

function kernelMigrationIds(directory: string): string[] {
  return readdirSync(directory)
    .filter((name) => name.endsWith(".cs") && !name.endsWith(".Designer.cs") && !name.endsWith("ModelSnapshot.cs"))
    .map((name) => name.slice(0, -3))
    .sort();
}

function sha256File(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function sha256Text(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

function idHash(db: DatabaseSync, table: string): { count: number; sha256: string } {
  const rows = db.prepare(`SELECT CAST(Id AS TEXT) AS Id FROM "${table}" ORDER BY Id`).all() as unknown as { Id: string }[];
  const hash = createHash("sha256");
  for (const row of rows) {
    hash.update(String(row.Id));
    hash.update("\n");
  }
  return { count: rows.length, sha256: hash.digest("hex") };
}

function historyIds(db: DatabaseSync, table: string): string[] {
  const exists = db.prepare("SELECT 1 AS ok FROM sqlite_master WHERE type = 'table' AND name = ?").get(table) as { ok: number } | undefined;
  if (!exists) return [];
  const rows = db.prepare(`SELECT MigrationId FROM "${table}" ORDER BY MigrationId`).all() as unknown as { MigrationId: string }[];
  return rows.map((row) => row.MigrationId);
}

function parseExtra(raw: string | null): Record<string, unknown> {
  if (!raw || raw.trim() === "") return {};
  const parsed = JSON.parse(raw) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("ExtraProperties is not an object");
  }
  return parsed as Record<string, unknown>;
}

function textOrNull(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new Error(`Expected string extra property, got ${typeof value}`);
  return value;
}

function boolOrFalse(value: unknown): number {
  if (value === undefined || value === null) return 0;
  if (typeof value === "boolean") return value ? 1 : 0;
  throw new Error(`Expected boolean extra property, got ${typeof value}`);
}

function snapshot(db: DatabaseSync, kernelHistoryTable: string) {
  return {
    weighingRecords: idHash(db, "WeighingRecords"),
    waybills: idHash(db, "Waybills"),
    waybillMaterials: idHash(db, "WaybillMaterials"),
    waybillAttachments: idHash(db, "WaybillAttachments"),
    weighingRecordAttachments: idHash(db, "WeighingRecordAttachments"),
    urbanExtensions: idHash(db, "UrbanWeighingExtensions"),
    recycleExtensions: idHash(db, "RecycleWaybillExtensions"),
    kernelHistory: historyIds(db, kernelHistoryTable),
    weighingModes: db.prepare("SELECT WeighingMode AS mode, COUNT(*) AS count FROM WeighingRecords GROUP BY WeighingMode ORDER BY WeighingMode").all(),
    waybillModes: db.prepare("SELECT WeighingMode AS mode, COUNT(*) AS count FROM Waybills GROUP BY WeighingMode ORDER BY WeighingMode").all(),
  };
}

function extensionContentHash(db: DatabaseSync): string {
  const waybills = db.prepare(`
    SELECT CAST(WaybillId AS TEXT) AS WaybillId, SolidWasteType, Street, SolidWasteOrderNumber, Shipper, UseIndependentDisplayedNet
    FROM SolidWasteWaybillExtensions
    ORDER BY WaybillId
  `).all() as unknown as Record<string, unknown>[];
  const records = db.prepare(`
    SELECT CAST(WeighingRecordId AS TEXT) AS WeighingRecordId, SolidWasteType, Street, SolidWasteOrderNumber, Shipper
    FROM SolidWasteWeighingExtensions
    ORDER BY WeighingRecordId
  `).all() as unknown as Record<string, unknown>[];
  return sha256Text(JSON.stringify({ waybills, records }, (_key, item) => typeof item === "bigint" ? item.toString() : item));
}

function insertMissing(
  db: DatabaseSync,
  table: "Waybills" | "WeighingRecords",
  idColumn: "WaybillId" | "WeighingRecordId",
  extensionTable: "SolidWasteWaybillExtensions" | "SolidWasteWeighingExtensions",
  keys: {
    typeKey: string;
    streetKey: string;
    orderKey: string;
    shipperKey: string;
    netKey: string;
    defaultShipper: string;
    maxOrderLength: number;
  },
  includeNet: boolean,
): number {
  const rows = db.prepare(`
    SELECT CAST(Id AS TEXT) AS Id, ExtraProperties, IsDeleted
    FROM "${table}"
    WHERE WeighingMode = ? AND IsDeleted = 0
    ORDER BY Id
  `).all(SolidWasteMode) as unknown as { Id: string; ExtraProperties: string | null }[];
  const known = new Set(
    (db.prepare(`SELECT CAST(${idColumn} AS TEXT) AS Id FROM "${extensionTable}"`).all() as unknown as { Id: string }[]).map((row) => row.Id),
  );
  const insertSql = includeNet
    ? `INSERT INTO "${extensionTable}" (Id, ${idColumn}, SolidWasteType, Street, SolidWasteOrderNumber, Shipper, UseIndependentDisplayedNet) VALUES (?, ?, ?, ?, ?, ?, ?)`
    : `INSERT INTO "${extensionTable}" (Id, ${idColumn}, SolidWasteType, Street, SolidWasteOrderNumber, Shipper) VALUES (?, ?, ?, ?, ?, ?)`;
  const insert = db.prepare(insertSql);
  let inserted = 0;
  for (const row of rows) {
    const id = row.Id;
    if (known.has(id)) continue;
    const extra = parseExtra(row.ExtraProperties);
    const orderNumber = textOrNull(extra[keys.orderKey]);
    if (orderNumber && orderNumber.length > keys.maxOrderLength) {
      throw new Error(`${table} ${id} order number length ${orderNumber.length} exceeds ${keys.maxOrderLength}`);
    }
    const shipperValue = extra[keys.shipperKey];
    const shipper = shipperValue === undefined || shipperValue === null ? keys.defaultShipper : textOrNull(shipperValue);
    const values: Array<string | bigint | null | number> = [
      randomUUID(),
      row.Id,
      textOrNull(extra[keys.typeKey]),
      textOrNull(extra[keys.streetKey]),
      orderNumber,
      shipper,
    ];
    if (includeNet) values.push(boolOrFalse(extra[keys.netKey]));
    insert.run(...values);
    inserted += 1;
  }
  return inserted;
}

function writeJson(path: string, value: unknown) {
  mkdirSync(dirname(path), { recursive: true });
  const text = JSON.stringify(value, (_key, item) => typeof item === "bigint" ? item.toString() : item, 2);
  writeFileSync(path, `${text}\n`, "utf8");
}

async function main(): Promise<number> {
  const repoRoot = arg("--repoRoot");
  const runDir = arg("--runDir");
  const config = yamlScalars(readFileSync(arg("--config"), "utf8"));
  const secretsPath = join(dirname(arg("--config")), "secrets.local.yaml");
  let sourceRelative = config.sourceDb;
  try {
    const secrets = yamlScalars(readFileSync(secretsPath, "utf8"));
    if (secrets.sourceDb) sourceRelative = secrets.sourceDb;
  } catch {
    // secrets.local.yaml is optional
  }
  const sourcePath = repoPath(repoRoot, sourceRelative);
  const workingPath = join(runDir, "working", config.workingDbName);
  mkdirSync(dirname(workingPath), { recursive: true });

  const sourceBefore = sha256File(sourcePath);
  const sourceDb = new DatabaseSync(sourcePath, { readOnly: true });
  await backup(sourceDb, workingPath);
  sourceDb.close();
  const sourceAfterCopy = sha256File(sourcePath);

  const extensionSource = readFileSync(repoPath(repoRoot, config.extensionSource), "utf8");
  const keys = {
    typeKey: readConstString(extensionSource, "SolidWasteTypeKey"),
    streetKey: readConstString(extensionSource, "StreetKey"),
    orderKey: readConstString(extensionSource, "SolidWasteOrderNumberKey"),
    shipperKey: readConstString(extensionSource, "ShipperKey"),
    netKey: readConstString(extensionSource, "UseIndependentDisplayedNetKey"),
    defaultShipper: readConstString(extensionSource, "DefaultShipper"),
    maxOrderLength: readConstInt(extensionSource, "MaxSolidWasteOrderNumberLength"),
  };
  const migrationSql = readMigrationSql(readFileSync(repoPath(repoRoot, config.solidWasteMigration), "utf8"));
  const expectedKernel = kernelMigrationIds(repoPath(repoRoot, config.kernelMigrationsDir));

  const db = new DatabaseSync(workingPath, { readBigInts: true });
  const pre = snapshot(db, config.kernelHistoryTable);
  writeJson(join(runDir, "prepare", "pre-schema.json"), pre);

  const productVersionRow = db.prepare(`SELECT ProductVersion FROM "${config.kernelHistoryTable}" ORDER BY MigrationId DESC LIMIT 1`).get() as { ProductVersion: string } | undefined;
  if (!productVersionRow) throw new Error("Kernel history has no ProductVersion");

  db.exec("BEGIN");
  db.exec(migrationSql);
  db.exec(`
    CREATE TABLE IF NOT EXISTS "${config.standardHistoryTable}" (
      "MigrationId" TEXT NOT NULL CONSTRAINT "PK_${config.standardHistoryTable}" PRIMARY KEY,
      "ProductVersion" TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS "${config.solidWasteHistoryTable}" (
      "MigrationId" TEXT NOT NULL CONSTRAINT "PK_${config.solidWasteHistoryTable}" PRIMARY KEY,
      "ProductVersion" TEXT NOT NULL
    );
  `);
  db.exec("COMMIT");

  const recordHistory = (table: string, migrationId: string) => {
    const existing = db.prepare(`SELECT 1 AS ok FROM "${table}" WHERE MigrationId = ?`).get(migrationId);
    if (!existing) {
      db.prepare(`INSERT INTO "${table}" (MigrationId, ProductVersion) VALUES (?, ?)`).run(migrationId, productVersionRow.ProductVersion);
    }
  };
  recordHistory(config.standardHistoryTable, config.standardMigrationId);
  recordHistory(config.solidWasteHistoryTable, config.solidWasteMigrationId);

  const firstWaybills = insertMissing(db, "Waybills", "WaybillId", "SolidWasteWaybillExtensions", keys, true);
  const firstRecords = insertMissing(db, "WeighingRecords", "WeighingRecordId", "SolidWasteWeighingExtensions", keys, false);
  const hashAfterFirst = extensionContentHash(db);
  const secondWaybills = insertMissing(db, "Waybills", "WaybillId", "SolidWasteWaybillExtensions", keys, true);
  const secondRecords = insertMissing(db, "WeighingRecords", "WeighingRecordId", "SolidWasteWeighingExtensions", keys, false);
  const hashAfterSecond = extensionContentHash(db);
  const post = snapshot(db, config.kernelHistoryTable);
  const standardHistory = historyIds(db, config.standardHistoryTable);
  const solidWasteHistory = historyIds(db, config.solidWasteHistoryTable);
  const standardModeExtensions = {
    weighingRecords: (db.prepare(`
      SELECT COUNT(*) AS count
      FROM SolidWasteWeighingExtensions e
      JOIN WeighingRecords w ON w.Id = e.WeighingRecordId
      WHERE w.WeighingMode <> ?
    `).get(SolidWasteMode) as { count: number }).count,
    waybills: (db.prepare(`
      SELECT COUNT(*) AS count
      FROM SolidWasteWaybillExtensions e
      JOIN Waybills w ON w.Id = e.WaybillId
      WHERE w.WeighingMode <> ?
    `).get(SolidWasteMode) as { count: number }).count,
  };
  db.close();
  const sourceAfter = sha256File(sourcePath);

  const kernelSame = JSON.stringify(pre.kernelHistory) === JSON.stringify(post.kernelHistory)
    && JSON.stringify(pre.kernelHistory) === JSON.stringify(expectedKernel);
  const keysSame = pre.weighingRecords.sha256 === post.weighingRecords.sha256
    && pre.waybills.sha256 === post.waybills.sha256
    && pre.weighingRecords.count === post.weighingRecords.count
    && pre.waybills.count === post.waybills.count
    && pre.waybillMaterials.sha256 === post.waybillMaterials.sha256
    && pre.waybillAttachments.sha256 === post.waybillAttachments.sha256
    && pre.weighingRecordAttachments.sha256 === post.weighingRecordAttachments.sha256
    && pre.urbanExtensions.sha256 === post.urbanExtensions.sha256
    && pre.recycleExtensions.sha256 === post.recycleExtensions.sha256;
  const historyApplied = standardHistory.includes(config.standardMigrationId) && solidWasteHistory.includes(config.solidWasteMigrationId);
  const backfillOk = secondWaybills === 0 && secondRecords === 0 && hashAfterFirst === hashAfterSecond
    && BigInt(standardModeExtensions.weighingRecords) === 0n
    && BigInt(standardModeExtensions.waybills) === 0n;
  const sourceUnchanged = sourceBefore === sourceAfterCopy && sourceAfterCopy === sourceAfter;
  const passed = sourceUnchanged && kernelSame && keysSame && historyApplied && backfillOk;

  const summary = {
    graphId: "standard-solidwaste-schema-upgrade",
    graphPath: "pipelines/graphs/materialclient/standard-solidwaste-schema-upgrade",
    runId: runDir.split(/[\\/]/).pop(),
    result: passed ? "pass" : "fail",
    sourceUnchanged,
    kernelHistoryUnchanged: kernelSame,
    kernelKeysUnchanged: keysSame,
    productHistoryApplied: historyApplied,
    backfillIdempotent: backfillOk,
    inserted: { waybills: firstWaybills, weighingRecords: firstRecords },
    secondPassInserted: { waybills: secondWaybills, weighingRecords: secondRecords },
    standardModeExtensions,
    observed: {
      P0: sourceUnchanged,
      P1: kernelSame && historyApplied,
      P2: keysSame && backfillOk,
      P3: false,
    },
  };
  writeJson(join(runDir, "schema", "post-schema.json"), {
    preCounts: {
      weighingRecords: pre.weighingRecords.count,
      waybills: pre.waybills.count,
    },
    postCounts: {
      weighingRecords: post.weighingRecords.count,
      waybills: post.waybills.count,
    },
    kernelHistory: post.kernelHistory,
    standardHistory,
    solidWasteHistory,
    weighingModes: post.weighingModes,
    waybillModes: post.waybillModes,
  });
  writeJson(join(runDir, "summary.json"), summary);
  writeFileSync(join(runDir, "report.md"), [
    "# standard-solidwaste-schema-upgrade",
    "",
    `result: ${summary.result}`,
    `sourceUnchanged: ${sourceUnchanged}`,
    `kernelHistoryUnchanged: ${kernelSame}`,
    `kernelKeysUnchanged: ${keysSame}`,
    `productHistoryApplied: ${historyApplied}`,
    `backfillIdempotent: ${backfillOk}`,
    `inserted waybills: ${firstWaybills}`,
    `inserted weighing records: ${firstRecords}`,
    "",
    "P3 is not set by this cook.",
    "",
  ].join("\n"), "utf8");
  console.log(JSON.stringify(summary));
  return passed ? 0 : 1;
}

main().then((code) => {
  process.exitCode = code;
}).catch((error: unknown) => {
  console.error(error instanceof Error ? error.stack ?? error.message : error);
  process.exitCode = 1;
});
