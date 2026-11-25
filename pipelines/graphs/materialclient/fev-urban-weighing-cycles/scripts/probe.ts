import { randomBytes } from "node:crypto";
import { closeSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setTimeout as sleep } from "node:timers/promises";

type Row = {
  id: number;
  tons: number;
  mode: number;
  cycleId: string | null;
  recoveryJson: string | null;
};

type ExtRow = {
  id: string;
  recordId: number;
  syncStatus: number;
  isAnomaly: number;
  anomalyReason: string | null;
};

type Cycle = {
  number: number;
  plate: string;
  tons: number;
  createMs: number | null;
  departMs: number | null;
  departed: boolean;
  rows: Row[];
  extCount: number;
  lockErrorsInCycle: number;
};

type HttpEntry = { path: string; request: object | undefined; status: number };

const [run, database, logRoot, revision, countArg, settleArg] = process.argv.slice(2);
if (!run || !database || !logRoot || !revision) {
  throw new Error("Expected run, database, logs and revision.");
}

const fixture = JSON.parse(readFileSync(new URL("../fixtures/scenario.json", import.meta.url), "utf8"));
if (countArg) fixture.cycles = Number(countArg);
if (settleArg === "0") fixture.departureSettleMs = 0;

const graphId = "fev-urban-weighing-cycles";
const graphPath = "pipelines/graphs/materialclient/" + graphId;
const runId = basename(run);

const http: HttpEntry[] = [];
const cycles: Cycle[] = [];
const issues: string[] = [];

const departure = /Normal flow completed \(normal departure\)|Abnormal departure from WeightStabilized/;
const locked = /SQLite Error (?:5|6):|\bSQLITE_(?:BUSY|LOCKED)\b|database (?:table )?is locked/i;
const recoveryRe = /Recovery|MarkRecovery|PersistRecovery|Sealed finalization|WeighingCycleRecovery/i;
const createErrRe = /Error occurred while creating weighing record|Create for cycle .* failed/i;

let p0 = false;
let setupComplete = false;
let p1 = false;
let p2 = false;
let result = "blocked";
let db: DatabaseSync | undefined;
let baselineLogs: Map<string, number> | undefined;
let logEvidence: string[] = [];
let recoveryStatuses: Record<string, number> = {};
let extSyncStatuses: Record<string, number> = {};
let sqliteLockErrorCount = 0;
let createErrorCount = 0;
let recoveryLogCount = 0;
let dbWeighingRecordCount = 0;
let dbUrbanExtensionCount = 0;

mkdirSync(join(run, ".."), { recursive: true });
mkdirSync(run);

function logFiles() {
  return readdirSync(logRoot, { recursive: true, withFileTypes: true })
    .filter(entry => entry.isFile() && entry.name.endsWith(".log"))
    .map(entry => join(entry.parentPath, entry.name));
}

function logOffsets() {
  return new Map(logFiles().map(path => [path, statSync(path).size]));
}

function logDelta(offsets: Map<string, number>) {
  return logFiles().map(path => {
    const size = statSync(path).size;
    const previous = offsets.get(path) ?? 0;
    const start = previous <= size ? previous : 0;
    if (start === size) return "";
    const bytes = Buffer.alloc(size - start);
    const fd = openSync(path, "r");
    try {
      return bytes.subarray(0, readSync(fd, bytes, 0, bytes.length, start)).toString("utf8");
    } finally {
      closeSync(fd);
    }
  }).join("\n");
}

async function request(path: string, body?: object) {
  const response = await fetch(new URL(path, fixture.baseUrl), {
    method: body ? "POST" : "GET",
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(10000),
  });
  http.push({ path, request: body, status: response.status });
  if (!response.ok) throw new Error(path + " returned HTTP " + response.status);
  const json = await response.json();
  if (body && json.success !== true) throw new Error(path + " did not acknowledge the input");
  return json;
}

async function until(timeoutMs: number, condition: () => boolean) {
  const deadline = Date.now() + timeoutMs;
  do {
    if (condition()) return true;
    await sleep(fixture.departureSettleMs === 0 ? 100 : 500);
  } while (Date.now() < deadline);
  return false;
}

try {
  db = new DatabaseSync(database, { readOnly: true, timeout: 5000 });
  const rowsForPlate = db.prepare(`
    SELECT Id AS id, CAST(TotalWeight AS REAL) AS tons, WeighingMode AS mode,
           CASE WHEN json_valid(ExtraProperties)
                THEN json_extract(ExtraProperties, '$.WeighingCycleId') END AS cycleId,
           CASE WHEN json_valid(ExtraProperties)
                THEN json_extract(ExtraProperties, '$.WeighingCycleRecovery') END AS recoveryJson
    FROM WeighingRecords WHERE PlateNumber = ?`);
  const extForRecord = db.prepare(`
    SELECT Id AS id, WeighingRecordId AS recordId, SyncStatus AS syncStatus,
           IsAnomaly AS isAnomaly, AnomalyReason AS anomalyReason
    FROM UrbanWeighingExtensions WHERE WeighingRecordId = ?`);
  const cycleCount = db.prepare(`
    SELECT COUNT(*) AS count FROM WeighingRecords
    WHERE CASE WHEN json_valid(ExtraProperties)
               THEN json_extract(ExtraProperties, '$.WeighingCycleId') END = ?`);

  const target = await request("/");
  const endpoints: string[] = target.endpoints ?? [];
  const hasScale = endpoints.some(e => e.includes("/api/scale/weight"));
  const hasPlate = endpoints.some(e => e.includes("/api/lpr/test-plate"));
  if (!hasScale || !hasPlate) {
    throw new Error("Diagnostic endpoints are missing.");
  }

  baselineLogs = logOffsets();
  p0 = true;

  await request("/api/scale/weight", { weight: fixture.offScaleTons });
  setupComplete = true;
  await sleep(fixture.initialSettleMs);

  for (let number = 1; number <= fixture.cycles; number++) {
    const plate = "浙A" + randomBytes(4).readUInt32BE().toString(36).toUpperCase().padStart(5, "0").slice(-5);
    if (cycles.some(c => c.plate === plate) || rowsForPlate.get(plate)) {
      throw new Error("Test plate collision.");
    }
    const tons = Number((fixture.firstStableTons + ((number - 1) % 10) * fixture.stableIncrementTons).toFixed(2));
    const cycle: Cycle = {
      number,
      plate,
      tons,
      createMs: null,
      departMs: null,
      departed: false,
      rows: [],
      extCount: 0,
      lockErrorsInCycle: 0,
    };
    cycles.push(cycle);

    const cycleStart = Date.now();
    const cycleLogStart = logOffsets();

    await request("/api/lpr/test-plate", { plateNumber: plate, deviceName: "UrbanWeighingCyclesFEV" });
    await request("/api/scale/weight", { weight: tons });

    const settled = await until(fixture.rowTimeoutMs, () => {
      cycle.rows = rowsForPlate.all(plate) as Row[];
      return cycle.rows.length > 0;
    });
    cycle.createMs = Date.now() - cycleStart;
    if (!settled) {
      issues.push(`Cycle ${number} (${plate}): no weighing record before timeout.`);
    } else {
      const exts = extForRecord.all(cycle.rows[0].id) as ExtRow[];
      cycle.extCount = exts.length;
    }

    const departStart = Date.now();
    const offsets = logOffsets();
    await request("/api/scale/weight", { weight: fixture.offScaleTons });
    cycle.departed = await until(fixture.departureTimeoutMs, () => departure.test(logDelta(offsets)));
    cycle.departMs = Date.now() - departStart;

    const cycleDelta = logDelta(cycleLogStart);
    cycle.lockErrorsInCycle = cycleDelta.split(/\r?\n/).filter(l => locked.test(l)).length;

    if (number % 10 === 0 || !settled || !cycle.departed || cycle.lockErrorsInCycle > 0) {
      console.log(
        `Cycle ${number}/${fixture.cycles} ${plate} ${tons}t | rows=${cycle.rows.length} ext=${cycle.extCount} createMs=${cycle.createMs} depart=${cycle.departed}(${cycle.departMs}ms) locks=${cycle.lockErrorsInCycle}`
      );
    }

    if (!cycle.departed) {
      issues.push(`Cycle ${number} (${plate}): departure not observed, stopping before the next cycle.`);
      break;
    }
    if (fixture.departureSettleMs > 0) await sleep(fixture.departureSettleMs);
  }

  if (fixture.postRunSettleMs > 0) {
    await sleep(fixture.postRunSettleMs);
  }

  p1 = cycles.length === fixture.cycles && cycles.every(c => c.departed);

  const identifiers = new Set<string>();
  for (const cycle of cycles) {
    cycle.rows = rowsForPlate.all(cycle.plate) as Row[];
    const row = cycle.rows[0];
    const id = row?.cycleId;
    const exts = row ? (extForRecord.all(row.id) as ExtRow[]) : [];
    cycle.extCount = exts.length;
    if (
      cycle.rows.length !== 1 ||
      !id ||
      row.mode !== fixture.expectedWeighingMode ||
      Math.abs(row.tons - cycle.tons) > fixture.weightToleranceTons ||
      identifiers.has(id) ||
      (cycleCount.get(id) as { count: number } | undefined)?.count !== 1 ||
      cycle.extCount !== 1
    ) {
      issues.push(`Cycle ${cycle.number} (${cycle.plate}): record count, extension count, CycleId, Urban mode or weight did not match.`);
    }
    if (id) identifiers.add(id);
  }

  const allRecords = db.prepare(`
    SELECT Id AS id,
           CASE WHEN json_valid(ExtraProperties)
                THEN json_extract(ExtraProperties, '$.WeighingCycleRecovery') END AS recoveryJson
    FROM WeighingRecords`).all() as { id: number; recoveryJson: string | null }[];
  dbWeighingRecordCount = allRecords.length;

  for (const r of allRecords) {
    let status = "MISSING";
    if (r.recoveryJson) {
      try {
        const doc = JSON.parse(r.recoveryJson);
        status = `${doc.Status}(attempts=${doc.AttemptCount},ended=${doc.CycleEnded})`;
      } catch {
        status = "INVALID_JSON";
      }
    }
    recoveryStatuses[status] = (recoveryStatuses[status] || 0) + 1;
  }

  const allExts = db.prepare(`SELECT SyncStatus AS syncStatus FROM UrbanWeighingExtensions`).all() as { syncStatus: number }[];
  dbUrbanExtensionCount = allExts.length;
  for (const e of allExts) {
    const key = String(e.syncStatus);
    extSyncStatuses[key] = (extSyncStatuses[key] || 0) + 1;
  }

  const delta = logDelta(baselineLogs);
  const lines = delta.split(/\r?\n/);
  sqliteLockErrorCount = lines.filter(l => locked.test(l)).length;
  createErrorCount = lines.filter(l => createErrRe.test(l)).length;
  recoveryLogCount = lines.filter(l => recoveryRe.test(l)).length;

  logEvidence = lines.filter(line =>
    locked.test(line) ||
    createErrRe.test(line) ||
    recoveryRe.test(line) ||
    /Urban polling:/.test(line) ||
    departure.test(line)
  );

  if (sqliteLockErrorCount > 0) {
    issues.push(`SQLite lock error observed during the run (${sqliteLockErrorCount} log lines).`);
  }

  p2 = p1 && issues.length === 0;
  result = p2 ? "pass" : "fail";
} catch (error) {
  issues.push(error instanceof Error ? error.message : String(error));
  if (setupComplete) {
    try {
      await request("/api/scale/weight", { weight: fixture.offScaleTons });
    } catch {
      issues.push("Could not restore the off-scale weight after the probe stopped.");
    }
  }
} finally {
  db?.close();
  const summary = {
    graphId,
    graphPath,
    runId,
    revision,
    result,
    p0,
    p1,
    p2,
    expected: fixture.cycles,
    departureSettleMs: fixture.departureSettleMs,
    dbWeighingRecordCount,
    dbUrbanExtensionCount,
    extSyncStatuses,
    recoveryStatuses,
    sqliteLockErrorCount,
    createErrorCount,
    recoveryLogCount,
    cycles,
    issues,
  };
  writeFileSync(join(run, "summary.json"), JSON.stringify(summary, null, 2));
  writeFileSync(join(run, "http.json"), JSON.stringify(http, null, 2));
  writeFileSync(join(run, "log-excerpt.txt"), logEvidence.join("\n"));
  writeFileSync(
    join(run, "manifest.yaml"),
    [
      "graphId: " + graphId,
      "graphPath: " + graphPath,
      "runId: " + runId,
      "result: " + result,
      "gitRevision: " + revision,
      "",
    ].join("\n")
  );
  writeFileSync(
    join(run, "report.md"),
    [
      "# Urban weighing cycles FEV",
      "",
      "- Result: " + result,
      "- Cycles observed: " + cycles.length,
      "- DB records / extensions: " + dbWeighingRecordCount + " / " + dbUrbanExtensionCount,
      "- SQLite lock error lines: " + sqliteLockErrorCount,
      "- P0 / P1 / P2: " + [p0, p1, p2].join(" / "),
      ...issues.map(issue => "- " + issue),
      "",
    ].join("\n")
  );
}

process.exitCode = result === "pass" ? 0 : result === "fail" ? 1 : 2;
