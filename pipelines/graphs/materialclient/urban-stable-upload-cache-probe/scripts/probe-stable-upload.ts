/**
 * Experimental probe: drive a running MaterialClient.Urban diagnostic host
 * and compare new SQLite rows plus log lines with fixtures/scenarios.json.
 * Does not reference repos/ types and does not delete database rows.
 */
import { execSync } from "node:child_process";
import { mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { DatabaseSync } from "node:sqlite";

type SyncName = "Pending" | "WeighingInProgress" | "Synced" | "Failed";

type Action = {
  plate?: string;
  weight?: "on" | "off" | "threshold";
  waitSeconds?: number;
  expect?: { count: number; sync: SyncName; plate?: string };
};

type Scenario = {
  id: string;
  uploadOnStable: boolean;
  actions: Action[];
};

type Fixture = {
  settleMs: number;
  onScaleTons: number;
  offScaleTons: number;
  thresholdTons: number;
  scenarios: Scenario[];
  optionalScenarios: Scenario[];
};

type Bill = {
  id: number;
  plate: string;
  weight: number;
  sync: number | null;
};

const SYNC: Record<SyncName, number> = {
  Pending: 0,
  Synced: 1,
  Failed: 2,
  WeighingInProgress: 3,
};

function argValue(flag: string): string | undefined {
  const index = process.argv.indexOf(flag);
  if (index < 0 || index + 1 >= process.argv.length) return undefined;
  return process.argv[index + 1];
}

function mustArg(flag: string): string {
  const value = argValue(flag);
  if (!value) throw new Error(`Missing ${flag}`);
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function writeText(path: string, text: string) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, "utf8");
}

async function requestJson(baseUrl: string, path: string, method: string, body?: unknown): Promise<{ status: number; json: unknown }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body === undefined ? undefined : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json: unknown = text;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  return { status: response.status, json };
}

function withDb<T>(databasePath: string, read: (db: DatabaseSync) => T): T {
  const db = new DatabaseSync(databasePath, { readOnly: true, timeout: 5000 });
  try {
    return read(db);
  } finally {
    db.close();
  }
}

function mapBills(rows: Array<{ id: number | bigint; plate: string; weight: number; sync: number | bigint | null }>): Bill[] {
  return rows.map((row) => ({
    id: Number(row.id),
    plate: row.plate ?? "",
    weight: Number(row.weight),
    sync: row.sync === null || row.sync === undefined ? null : Number(row.sync),
  }));
}

function listBills(databasePath: string, afterId: number): Bill[] {
  const select = `
    SELECT r.Id AS id, IFNULL(r.PlateNumber, '') AS plate, r.TotalWeight AS weight, e.SyncStatus AS sync
    FROM WeighingRecords r
    LEFT JOIN UrbanWeighingExtensions e ON e.WeighingRecordId = r.Id`;
  return withDb(databasePath, (db) => {
    try {
      const rows = db.prepare(`${select} WHERE r.Id > ? AND IFNULL(r.IsDeleted, 0) = 0 ORDER BY r.Id`).all(afterId) as Array<{
        id: number | bigint;
        plate: string;
        weight: number;
        sync: number | bigint | null;
      }>;
      return mapBills(rows);
    } catch {
      const rows = db.prepare(`${select} WHERE r.Id > ? ORDER BY r.Id`).all(afterId) as Array<{
        id: number | bigint;
        plate: string;
        weight: number;
        sync: number | bigint | null;
      }>;
      return mapBills(rows);
    }
  });
}

function maxId(databasePath: string): number {
  return withDb(databasePath, (db) => {
    const row = db.prepare("SELECT IFNULL(MAX(Id), 0) AS id FROM WeighingRecords").get() as { id: number | bigint };
    return Number(row.id);
  });
}

function syncMatches(expected: SyncName, actual: number | null): boolean {
  if (actual === null || actual === undefined) return false;
  if (expected === "WeighingInProgress") return actual === SYNC.WeighingInProgress;
  return actual !== SYNC.WeighingInProgress;
}

function logFiles(logRoot: string): string[] {
  const found: string[] = [];
  const walk = (dir: string) => {
    let entries: string[] = [];
    try {
      entries = readdirSync(dir);
    } catch {
      return;
    }
    for (const name of entries) {
      const path = join(dir, name);
      let info;
      try {
        info = statSync(path);
      } catch {
        continue;
      }
      if (info.isDirectory()) walk(path);
      else if (name.includes("MaterialClient.Urban") && name.endsWith(".log")) found.push(path);
    }
  };
  walk(logRoot);
  return found;
}

function snapshotLogs(logRoot: string): Map<string, number> {
  const sizes = new Map<string, number>();
  for (const file of logFiles(logRoot)) {
    try {
      sizes.set(file, statSync(file).size);
    } catch {
      sizes.set(file, 0);
    }
  }
  return sizes;
}

function newLogText(logRoot: string, before: Map<string, number>): string {
  const chunks: string[] = [];
  for (const file of logFiles(logRoot)) {
    const start = before.get(file) ?? 0;
    let size = start;
    try {
      size = statSync(file).size;
    } catch {
      continue;
    }
    if (size <= start) continue;
    const data = readFileSync(file);
    chunks.push(data.subarray(start).toString("utf8"));
  }
  return chunks.join("\n");
}

type SettingsBag = Record<string, unknown> & {
  scaleSettings?: { scaleType?: number | string };
  weighingConfiguration?: { enableUploadOnStable?: boolean };
};

async function main() {
  const runDir = mustArg("--run");
  const baseUrl = mustArg("--baseUrl").replace(/\/$/, "");
  const databasePath = mustArg("--database");
  const logRoot = mustArg("--log");
  const fixturePath = mustArg("--fixture");
  const includeFallback = process.argv.includes("--include-fallback");
  const repoRoot = mustArg("--repo");
  const fixture = readJson<Fixture>(fixturePath);
  const httpLog: unknown[] = [];
  const scenarioReports: unknown[] = [];
  let result: "pass" | "fail" | "blocked" = "fail";
  let p0 = "fail";
  let p1 = "fail";
  let p2 = "fail";
  let restored = false;
  let originalSettings: SettingsBag | undefined;
  const logBefore = snapshotLogs(logRoot);

  const recordHttp = (entry: unknown) => {
    httpLog.push(entry);
  };

  try {
    let root: { status: number; json: unknown };
    try {
      root = await requestJson(baseUrl, "/", "GET");
    } catch (error) {
      result = "blocked";
      p0 = "blocked";
      throw new Error(`Diagnostic host is not reachable at ${baseUrl}. Start scripts/MaterialClient/Start-MaterialClient.Urban.ps1 -EnableDiagnosticHost. ${String(error)}`);
    }
    recordHttp({ path: "/", status: root.status });
    if (root.status !== 200) {
      result = "blocked";
      p0 = "blocked";
      throw new Error(`GET / returned ${root.status}`);
    }
    p0 = "pass";

    const settingsResponse = await requestJson(baseUrl, "/api/settings", "GET");
    recordHttp({ path: "/api/settings", method: "GET", status: settingsResponse.status });
    if (settingsResponse.status !== 200) {
      result = "blocked";
      throw new Error(`GET /api/settings returned ${settingsResponse.status}`);
    }
    const wrapped = settingsResponse.json as { settings?: SettingsBag };
    if (!wrapped.settings) throw new Error("GET /api/settings has no settings object");
    originalSettings = structuredClone(wrapped.settings);

    maxId(databasePath);
    const scenarios = includeFallback ? [...fixture.scenarios, ...fixture.optionalScenarios] : fixture.scenarios;
    let operated = false;

    for (const scenario of scenarios) {
      const settings = structuredClone(originalSettings);
      settings.scaleSettings = { ...(settings.scaleSettings ?? {}), scaleType: 2 };
      settings.weighingConfiguration = {
        ...(settings.weighingConfiguration ?? {}),
        enableUploadOnStable: scenario.uploadOnStable,
      };
      const saved = await requestJson(baseUrl, "/api/settings", "POST", settings);
      recordHttp({ scenario: scenario.id, path: "/api/settings", method: "POST", status: saved.status });
      if (saved.status !== 200) {
        scenarioReports.push({ id: scenario.id, pass: false, detail: `settings POST ${saved.status}` });
        continue;
      }
      await sleep(1000);
      const prelude = await requestJson(baseUrl, "/api/scale/weight", "POST", { weight: fixture.offScaleTons });
      recordHttp({ scenario: scenario.id, path: "/api/scale/weight", status: prelude.status, weight: fixture.offScaleTons, prelude: true });
      if (prelude.status !== 200) {
        scenarioReports.push({ id: scenario.id, pass: false, detail: `prelude scale/weight ${prelude.status} ${JSON.stringify(prelude.json)}` });
        continue;
      }
      await sleep(fixture.settleMs);
      const baseline = maxId(databasePath);
      const plateToken = `P${Date.now().toString(36)}`;
      const plateOf = (letter: string) => `${plateToken}${letter}`;
      let failed = "";
      for (const action of scenario.actions) {
        if (action.plate) {
          const plate = plateOf(action.plate);
          const posted = await requestJson(baseUrl, "/api/lpr/test-plate", "POST", { plateNumber: plate });
          recordHttp({ scenario: scenario.id, path: "/api/lpr/test-plate", status: posted.status, plate });
          operated = true;
          if (posted.status !== 200) {
            failed = `test-plate ${posted.status}`;
            break;
          }
        }
        if (action.weight) {
          const tons = action.weight === "on" ? fixture.onScaleTons : action.weight === "off" ? fixture.offScaleTons : fixture.thresholdTons;
          const posted = await requestJson(baseUrl, "/api/scale/weight", "POST", { weight: tons });
          recordHttp({ scenario: scenario.id, path: "/api/scale/weight", status: posted.status, weight: tons });
          operated = true;
          if (posted.status !== 200) {
            failed = `scale/weight ${posted.status} ${JSON.stringify(posted.json)}`;
            break;
          }
          await sleep(fixture.settleMs);
        }
        if (action.waitSeconds) await sleep(action.waitSeconds * 1000);
        if (action.expect) {
          const bills = listBills(databasePath, baseline);
          const expectedPlate = action.expect.plate ? plateOf(action.expect.plate) : undefined;
          const countOk = bills.length === action.expect.count;
          const latest = bills[bills.length - 1];
          const syncOk = action.expect.count === 0 || syncMatches(action.expect.sync, latest?.sync ?? null);
          const plateOk = !expectedPlate || bills.some((bill) => bill.plate === expectedPlate);
          if (!countOk || !syncOk || !plateOk) {
            failed = `expected count ${action.expect.count} sync ${action.expect.sync} plate ${expectedPlate ?? "*"}; got ${JSON.stringify(bills)}`;
            break;
          }
        }
      }
      const off = await requestJson(baseUrl, "/api/scale/weight", "POST", { weight: fixture.offScaleTons });
      recordHttp({ scenario: scenario.id, path: "/api/scale/weight", status: off.status, weight: fixture.offScaleTons, cleanup: true });
      await sleep(fixture.settleMs);
      scenarioReports.push({ id: scenario.id, pass: failed === "", detail: failed || "ok", baseline });
    }
    p1 = operated ? "pass" : "fail";
    p2 = scenarioReports.every((item) => (item as { pass: boolean }).pass) ? "pass" : "fail";
    result = p1 === "pass" && p2 === "pass" ? "pass" : "fail";
  } catch (error) {
    scenarioReports.push({ id: "cook", pass: false, detail: error instanceof Error ? error.message : String(error) });
    if (result !== "blocked") result = "fail";
  } finally {
    if (originalSettings) {
      try {
        const restoredResponse = await requestJson(baseUrl, "/api/settings", "POST", originalSettings);
        restored = restoredResponse.status === 200;
        recordHttp({ path: "/api/settings", method: "POST", restore: true, status: restoredResponse.status });
      } catch (error) {
        recordHttp({ path: "/api/settings", restore: true, error: String(error) });
      }
    }
    const logText = newLogText(logRoot, logBefore);
    const interesting = logText
      .split(/\r?\n/)
      .filter((line) =>
        /Created weighing record successfully|Skipped weighing record create|Released produced-plate hold|Scale test weight injected|Test plate injected|Full settings saved/.test(line))
      .slice(-200);
    writeText(join(runDir, "log-excerpt.txt"), interesting.join("\n") + "\n");
    writeText(join(runDir, "http.json"), JSON.stringify(httpLog, null, 2) + "\n");
    let git = "";
    try {
      git = execSync("git rev-parse --short HEAD", { cwd: repoRoot, encoding: "utf8" }).trim();
    } catch {
      git = "";
    }
    const summary = {
      graphId: "urban-stable-upload-cache-probe",
      graphPath: "pipelines/graphs/materialclient/urban-stable-upload-cache-probe",
      runId: runDir.split(/[\\/]/).at(-1),
      result,
      gitRevision: git,
      includeFallback,
      settingsRestored: restored,
      levels: { P0: p0, P1: p1, P2: p2, P3: "not-judged" },
      scenarios: scenarioReports,
      logLineCount: interesting.length,
    };
    writeText(join(runDir, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
    const lines = [
      "# urban-stable-upload-cache-probe",
      "",
      `result: ${result}`,
      `P0: ${p0}`,
      `P1: ${p1}`,
      `P2: ${p2}`,
      "P3: not-judged",
      `settingsRestored: ${restored}`,
      `includeFallback: ${includeFallback}`,
      "",
      ...scenarioReports.map((item) => {
        const row = item as { id: string; pass: boolean; detail: string };
        return `- ${row.pass ? "pass" : "fail"} ${row.id}: ${row.detail}`;
      }),
      "",
      "UI was not read. New log lines are in log-excerpt.txt. Row checks used the local SQLite file.",
      "",
    ];
    writeText(join(runDir, "report.md"), lines.join("\n"));
    const graphPath = "pipelines/graphs/materialclient/urban-stable-upload-cache-probe";
    const manifest = [
      `graphId: urban-stable-upload-cache-probe`,
      `graphPath: ${graphPath}`,
      `runId: ${summary.runId}`,
      `result: ${result}`,
      `gitRevision: "${git}"`,
      `contractPath: ${graphPath}/contract.yaml`,
      "artifacts:",
      "  - summary.json",
      "  - report.md",
      "  - http.json",
      "  - log-excerpt.txt",
      "",
    ].join("\n");
    writeText(join(runDir, "manifest.yaml"), manifest);
    const shown = relative(repoRoot, runDir).replace(/\\/g, "/");
    console.log(shown || summary.runId);
  }

  if (result !== "pass") process.exit(result === "blocked" ? 2 : 1);
}

main();
