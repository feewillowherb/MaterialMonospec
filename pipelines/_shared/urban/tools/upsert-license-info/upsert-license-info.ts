#!/usr/bin/env node
import { mkdirSync, readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

interface LicenseSeed {
  id: string;
  projectId: string;
  accessCode?: string | null;
  authEndTime: string;
  proName?: string | null;
  machineCode: string;
  latestJwtToken?: string | null;
}

function usage(): never {
  console.error("Usage: upsert-license-info <databasePath> <licenseJsonPath>");
  process.exit(1);
}

function getRequiredGuid(root: LicenseSeed, name: keyof LicenseSeed): string {
  const value = root[name];
  if (typeof value !== "string" || !/^[0-9a-f-]{36}$/i.test(value.trim())) {
    throw new Error(`Missing or invalid GUID field '${name}'.`);
  }
  return value.trim();
}

function getRequiredString(root: LicenseSeed, name: keyof LicenseSeed): string {
  const value = root[name];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Missing or invalid string field '${name}'.`);
  }
  return value.trim();
}

function getOptionalString(root: LicenseSeed, name: keyof LicenseSeed): string | null {
  const value = root[name];
  if (value == null) {
    return null;
  }
  if (typeof value !== "string") {
    throw new Error(`Invalid string field '${name}'.`);
  }
  const text = value.trim();
  return text.length === 0 ? null : text;
}

function getRequiredDateTime(root: LicenseSeed, name: keyof LicenseSeed): Date {
  const value = root[name];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Missing datetime field '${name}'.`);
  }
  const parsed = new Date(value.trim());
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Missing or invalid datetime field '${name}'.`);
  }
  return parsed;
}

/** Align with EF Core / Microsoft.Data.Sqlite: yyyy-MM-dd HH:mm:ss.fffffff */
function formatEfDateTime(date: Date, useUtc: boolean): string {
  const year = useUtc ? date.getUTCFullYear() : date.getFullYear();
  const month = (useUtc ? date.getUTCMonth() : date.getMonth()) + 1;
  const day = useUtc ? date.getUTCDate() : date.getDate();
  const hours = useUtc ? date.getUTCHours() : date.getHours();
  const minutes = useUtc ? date.getUTCMinutes() : date.getMinutes();
  const seconds = useUtc ? date.getUTCSeconds() : date.getSeconds();
  const millis = useUtc ? date.getUTCMilliseconds() : date.getMilliseconds();
  const frac = `${millis.toString().padStart(3, "0")}0000`;

  const pad2 = (n: number) => n.toString().padStart(2, "0");
  return `${year}-${pad2(month)}-${pad2(day)} ${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)}.${frac}`;
}

function main(): void {
  const [, , databaseArg, licenseJsonArg] = process.argv;
  if (!databaseArg || !licenseJsonArg) {
    usage();
  }

  const databasePath = resolve(databaseArg);
  const licenseJsonPath = resolve(licenseJsonArg);

  if (!existsSync(licenseJsonPath)) {
    console.error(`License JSON not found: ${licenseJsonPath}`);
    process.exit(1);
  }

  const root = JSON.parse(readFileSync(licenseJsonPath, "utf8")) as LicenseSeed;

  const id = getRequiredGuid(root, "id");
  const projectId = getRequiredGuid(root, "projectId");
  const accessCode = getOptionalString(root, "accessCode");
  const authEndTime = getRequiredDateTime(root, "authEndTime");
  const proName = getOptionalString(root, "proName");
  const machineCode = getRequiredString(root, "machineCode");
  const latestJwtToken = getOptionalString(root, "latestJwtToken");

  const dbDirectory = dirname(databasePath);
  if (dbDirectory.length > 0) {
    mkdirSync(dbDirectory, { recursive: true });
  }

  const now = formatEfDateTime(new Date(), true);
  const authEndTimeText = formatEfDateTime(authEndTime, false);

  const db = new DatabaseSync(databasePath);
  try {
    db.exec("PRAGMA foreign_keys = OFF;");
    db.exec("DELETE FROM LicenseInfo;");
    db.prepare(
      `INSERT INTO LicenseInfo (
        Id, ProjectId, AuthEndTime, MachineCode, AccessCode, ProName, LatestJwtToken,
        CreatedAt, UpdatedAt, CreatorId, LastModifierId
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?,
        ?, ?, NULL, NULL
      );`,
    ).run(
      id,
      projectId,
      authEndTimeText,
      machineCode,
      accessCode,
      proName,
      latestJwtToken,
      now,
      now,
    );
  } finally {
    db.close();
  }

  const authSummary = authEndTimeText.slice(0, 19);
  console.log(
    `LicenseInfo upserted: Id=${id}, ProjectId=${projectId}, AuthEndTime=${authSummary}`,
  );
}

try {
  main();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
}
