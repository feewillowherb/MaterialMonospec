/**
 * experimental: set SolidWasteInfo.UseIndependentDisplayedNet on matched Waybills.
 * Usage (from pipelines/):
 *   pnpm exec tsx graphs/.../set-independent-net-flag.ts --database <path> --runDir <dir> --scenarioJson <path> [--write]
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";

type Target = {
  plateNumber: string;
  joinTime: string;
  outTime: string;
};

type Scenario = {
  dryRun: boolean;
  flagKey: string;
  flagValue: boolean;
  targets: Target[];
};

type RowHit = {
  target: Target;
  id: number | bigint;
  plateNumber: string;
  joinTime: string;
  outTime: string;
  gross: unknown;
  tare: unknown;
  net: unknown;
  extraBefore: string;
  extraAfter: string;
  alreadySet: boolean;
};

function argValue(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  if (i < 0 || i + 1 >= process.argv.length) return undefined;
  return process.argv[i + 1];
}

function hasFlag(name: string): boolean {
  return process.argv.includes(name);
}

function secondPrefix(isoLocal: string): string {
  // "2026-11-04 07:51:17" or with fractional seconds
  return isoLocal.trim().slice(0, 19);
}

function mergeFlag(extraRaw: string | null | undefined, key: string, value: boolean): {
  json: string;
  alreadySet: boolean;
} {
  let obj: Record<string, unknown> = {};
  const raw = (extraRaw ?? "").trim();
  if (raw.length > 0) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        obj = parsed as Record<string, unknown>;
      }
    } catch {
      throw new Error(`ExtraProperties is not valid JSON (len=${raw.length})`);
    }
  }
  const alreadySet = obj[key] === true || obj[key] === "true" || obj[key] === 1;
  obj[key] = value;
  return { json: JSON.stringify(obj), alreadySet };
}

function main(): void {
  const database = argValue("--database");
  const runDir = argValue("--runDir");
  const scenarioJson = argValue("--scenarioJson");
  const write = hasFlag("--write");

  if (!database || !runDir || !scenarioJson) {
    throw new Error("Required: --database --runDir --scenarioJson [--write]");
  }

  mkdirSync(join(runDir, "prepare"), { recursive: true });

  const scenario = JSON.parse(readFileSync(scenarioJson, "utf8")) as Scenario;
  const dryRun = scenario.dryRun !== false && !write;
  const flagKey = scenario.flagKey || "SolidWasteInfo.UseIndependentDisplayedNet";
  const flagValue = scenario.flagValue !== false;

  const db = new DatabaseSync(database);
  const hits: RowHit[] = [];
  const errors: string[] = [];

  const selectStmt = db.prepare(
    `SELECT Id, PlateNumber, JoinTime, OutTime, OrderTotalWeight, OrderTruckWeight, OrderGoodsWeight, ExtraProperties
     FROM Waybills
     WHERE PlateNumber = ?
       AND substr(JoinTime, 1, 19) = ?
       AND substr(OutTime, 1, 19) = ?`,
  );

  for (const t of scenario.targets ?? []) {
    const joinP = secondPrefix(t.joinTime);
    const outP = secondPrefix(t.outTime);
    const rows = selectStmt.all(t.plateNumber, joinP, outP) as Array<Record<string, unknown>>;
    if (rows.length !== 1) {
      errors.push(
        `target ${t.plateNumber} join=${joinP} out=${outP}: expected 1 row, got ${rows.length}`,
      );
      continue;
    }
    const r = rows[0];
    const extraBefore = String(r.ExtraProperties ?? "");
    const merged = mergeFlag(extraBefore, flagKey, flagValue);
    hits.push({
      target: t,
      id: r.Id as number | bigint,
      plateNumber: String(r.PlateNumber),
      joinTime: String(r.JoinTime),
      outTime: String(r.OutTime),
      gross: r.OrderTotalWeight,
      tare: r.OrderTruckWeight,
      net: r.OrderGoodsWeight,
      extraBefore,
      extraAfter: merged.json,
      alreadySet: merged.alreadySet,
    });
  }

  writeFileSync(
    join(runDir, "prepare", "locate.json"),
    JSON.stringify({ hits, errors, dryRun, flagKey, flagValue }, null, 2),
    "utf8",
  );

  if (errors.length > 0) {
    writeFileSync(
      join(runDir, "summary.json"),
      JSON.stringify({ result: "fail", dryRun, errors, hits }, null, 2),
      "utf8",
    );
    writeFileSync(
      join(runDir, "report.md"),
      `# solidwaste-legacy-net-flag-ingest\n\n**result:** fail\n\n${errors.map((e) => `- ${e}`).join("\n")}\n`,
      "utf8",
    );
    console.error(errors.join("\n"));
    process.exit(1);
  }

  if (!dryRun) {
    // node:sqlite DatabaseSync has no .transaction(); snowflake Ids via TEXT to avoid RangeError
    const upd = db.prepare(
      `UPDATE Waybills SET ExtraProperties = ? WHERE CAST(Id AS TEXT) = ?`,
    );
    for (const h of hits) {
      upd.run(h.extraAfter, String(h.id));
    }
  }

  // re-read when write
  const verified: Array<{ id: unknown; flag: unknown }> = [];
  if (!dryRun) {
    const getOne = db.prepare(
      `SELECT Id, ExtraProperties FROM Waybills WHERE CAST(Id AS TEXT) = ?`,
    );
    for (const h of hits) {
      const row = getOne.get(String(h.id)) as
        | { Id: unknown; ExtraProperties: string }
        | undefined;
      const extra = row?.ExtraProperties ? JSON.parse(row.ExtraProperties) : {};
      verified.push({ id: String(h.id), flag: extra[flagKey] });
      if (extra[flagKey] !== true) {
        errors.push(`verify failed Id=${String(h.id)} flag=${String(extra[flagKey])}`);
      }
    }
  }

  try {
    db.close();
  } catch {
    /* ignore */
  }

  const result = errors.length > 0 ? "fail" : dryRun ? "pass" : "pass";
  const summary = {
    result,
    dryRun,
    flagKey,
    flagValue,
    updated: dryRun ? 0 : hits.length,
    hits: hits.map((h) => ({
      id: String(h.id),
      plateNumber: h.plateNumber,
      joinTime: h.joinTime,
      outTime: h.outTime,
      weights: { G: h.gross, T: h.tare, N: h.net },
      alreadySet: h.alreadySet,
    })),
    verified,
    errors,
  };

  writeFileSync(join(runDir, "summary.json"), JSON.stringify(summary, null, 2), "utf8");
  const lines = [
    `# solidwaste-legacy-net-flag-ingest`,
    ``,
    `**result:** ${result}`,
    `**dryRun:** ${dryRun}`,
    `**flag:** \`${flagKey}\` = ${flagValue}`,
    `**rows:** ${hits.length}`,
    ``,
    `| Id | Plate | Join | Already |`,
    `|----|-------|------|---------|`,
    ...hits.map(
      (h) =>
        `| ${String(h.id)} | ${h.plateNumber} | ${secondPrefix(h.joinTime)} | ${h.alreadySet} |`,
    ),
    ``,
    dryRun
      ? `_Dry-run only. Re-run with -Write to persist._`
      : `_Wrote ExtraProperties merge on ${hits.length} Waybill(s)._`,
    ``,
  ];
  writeFileSync(join(runDir, "report.md"), lines.join("\n"), "utf8");

  if (errors.length > 0) process.exit(1);
  console.log(JSON.stringify({ result, dryRun, count: hits.length }));
}

main();
