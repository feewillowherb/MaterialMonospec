/**
 * Experimental FEV: burst four test-scale targets with no settle between them.
 * A backlog is observed when the HTTP burst returns before any new weighing row exists.
 * After the queue drains, expect gross then tare, then one SolidWaste Waybill.
 * Does not ProjectReference repos/. Does not read or store an activation code.
 */
import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { DatabaseSync } from "node:sqlite";

type Fixture = {
  grossTons: number;
  tareTons: number;
  offScaleTons: number;
  weightToleranceTons: number;
  weighingMode: number;
  preludeSettleMs: number;
  drainWaitMs: number;
  pollMs: number;
  expectRecords: number;
  expectWaybills: number;
};

type Bill = {
  id: number;
  plate: string;
  weight: number;
  weighingMode: number;
  waybillId: number | null;
};

type WaybillHit = {
  id: number;
  plate: string;
  weighingMode: number;
};

const GRAPH_ID = "fev-solidwaste-extreme-condition";
const GRAPH_PATH = "pipelines/graphs/materialclient/fev-solidwaste-extreme-condition";

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

async function requestJson(
  baseUrl: string,
  path: string,
  method: string,
  body?: unknown,
): Promise<{ status: number; json: unknown; elapsedMs: number }> {
  const started = Date.now();
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
  return { status: response.status, json, elapsedMs: Date.now() - started };
}

function withDb<T>(databasePath: string, read: (db: DatabaseSync) => T): T {
  const db = new DatabaseSync(databasePath, { readOnly: true, timeout: 5000 });
  try {
    return read(db);
  } finally {
    db.close();
  }
}

function maxId(databasePath: string, table: string): number {
  return withDb(databasePath, (db) => {
    const row = db.prepare(`SELECT COALESCE(MAX(Id), 0) AS maxId FROM ${table}`).get() as {
      maxId: number | bigint;
    };
    return Number(row.maxId);
  });
}

function listBills(databasePath: string, afterId: number): Bill[] {
  return withDb(databasePath, (db) => {
    const rows = db
      .prepare(
        `SELECT Id AS id, COALESCE(PlateNumber, '') AS plate, TotalWeight AS weight,
                WeighingMode AS weighingMode, WaybillId AS waybillId
         FROM WeighingRecords
         WHERE Id > ?
         ORDER BY Id ASC`,
      )
      .all(afterId) as Array<{
      id: number | bigint;
      plate: string;
      weight: number;
      weighingMode: number | bigint;
      waybillId: number | bigint | null;
    }>;
    return rows.map((row) => ({
      id: Number(row.id),
      plate: row.plate,
      weight: Number(row.weight),
      weighingMode: Number(row.weighingMode),
      waybillId: row.waybillId == null ? null : Number(row.waybillId),
    }));
  });
}

function listWaybills(databasePath: string, afterId: number): WaybillHit[] {
  return withDb(databasePath, (db) => {
    const rows = db
      .prepare(
        `SELECT Id AS id, COALESCE(PlateNumber, '') AS plate, WeighingMode AS weighingMode
         FROM Waybills
         WHERE Id > ? AND IFNULL(IsDeleted, 0) = 0
         ORDER BY Id ASC`,
      )
      .all(afterId) as Array<{
      id: number | bigint;
      plate: string;
      weighingMode: number | bigint;
    }>;
    return rows.map((row) => ({
      id: Number(row.id),
      plate: row.plate,
      weighingMode: Number(row.weighingMode),
    }));
  });
}

function snapshotLogs(logRoot: string): Map<string, number> {
  const map = new Map<string, number>();
  const walk = (dir: string) => {
    const st = statSync(dir, { throwIfNoEntry: false });
    if (!st?.isDirectory()) return;
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const child = statSync(full, { throwIfNoEntry: false });
      if (!child) continue;
      if (child.isDirectory()) walk(full);
      else if (child.isFile()) map.set(relative(logRoot, full), child.size);
    }
  };
  walk(logRoot);
  return map;
}

function newLogText(logRoot: string, before: Map<string, number>): string {
  const chunks: string[] = [];
  const walk = (dir: string) => {
    const st = statSync(dir, { throwIfNoEntry: false });
    if (!st?.isDirectory()) return;
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const child = statSync(full, { throwIfNoEntry: false });
      if (!child) continue;
      if (child.isDirectory()) {
        walk(full);
        continue;
      }
      if (!child.isFile()) continue;
      const key = relative(logRoot, full);
      const prev = before.get(key) ?? 0;
      if (child.size <= prev) continue;
      const buf = readFileSync(full);
      chunks.push(buf.subarray(prev).toString("utf8"));
    }
  };
  walk(logRoot);
  return chunks.join("\n");
}

function near(a: number, b: number, tol: number): boolean {
  return Math.abs(a - b) <= tol;
}

function makePlate(): string {
  const suffix = Date.now().toString(36).toUpperCase().replace(/[^A-Z0-9]/g, "A").slice(-5).padStart(5, "A");
  return `浙A${suffix}`;
}

async function main() {
  const runDir = mustArg("--run");
  const baseUrl = mustArg("--baseUrl").replace(/\/$/, "");
  const databasePath = mustArg("--database");
  const logRoot = mustArg("--log");
  const fixturePath = mustArg("--fixture");
  const repoRoot = mustArg("--repo");
  const fixture = readJson<Fixture>(fixturePath);

  const httpLog: unknown[] = [];
  let result: "pass" | "fail" | "blocked" = "fail";
  let p0 = "fail";
  let p1 = "fail";
  let p2 = "fail";
  let fevVerdict: "FEASIBLE" | "INFEASIBLE" | "INCONCLUSIVE" = "INCONCLUSIVE";
  let detail = "";
  let bills: Bill[] = [];
  let waybills: WaybillHit[] = [];
  let logText = "";
  let plate = "";
  let backlogObserved = false;
  let burstElapsedMs = 0;
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
      fevVerdict = "INCONCLUSIVE";
      throw new Error(
        `Diagnostic host is not reachable at ${baseUrl}. Start scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost. ${String(error)}`,
      );
    }
    recordHttp({ path: "/", status: root.status, elapsedMs: root.elapsedMs });
    if (root.status !== 200) {
      result = "blocked";
      p0 = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(`GET / returned ${root.status}`);
    }
    p0 = "pass";

    const prelude = await requestJson(baseUrl, "/api/scale/weight", "POST", {
      weight: fixture.offScaleTons,
    });
    recordHttp({
      path: "/api/scale/weight",
      status: prelude.status,
      weight: fixture.offScaleTons,
      phase: "prelude",
      elapsedMs: prelude.elapsedMs,
      body: prelude.json,
    });
    if (prelude.status !== 200) {
      result = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(
        `prelude scale/weight ${prelude.status} ${JSON.stringify(prelude.json)}. Need ScaleType=TestMode and the SolidWaste weighing window.`,
      );
    }
    await sleep(fixture.preludeSettleMs);

    const baseline = maxId(databasePath, "WeighingRecords");
    const waybillBaseline = maxId(databasePath, "Waybills");
    plate = makePlate();
    const platePosted = await requestJson(baseUrl, "/api/lpr/test-plate", "POST", {
      plateNumber: plate,
    });
    recordHttp({
      path: "/api/lpr/test-plate",
      status: platePosted.status,
      plate,
      elapsedMs: platePosted.elapsedMs,
      body: platePosted.json,
    });
    if (platePosted.status !== 200) {
      result = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(`test-plate ${platePosted.status} ${JSON.stringify(platePosted.json)}`);
    }

    const burst = [
      { phase: "gross", weight: fixture.grossTons },
      { phase: "off-between", weight: fixture.offScaleTons },
      { phase: "tare", weight: fixture.tareTons },
      { phase: "off-after", weight: fixture.offScaleTons },
    ];
    const burstStarted = Date.now();
    for (const step of burst) {
      const posted = await requestJson(baseUrl, "/api/scale/weight", "POST", { weight: step.weight });
      recordHttp({
        path: "/api/scale/weight",
        status: posted.status,
        weight: step.weight,
        phase: step.phase,
        elapsedMs: posted.elapsedMs,
        body: posted.json,
      });
      if (posted.status !== 200) {
        result = "blocked";
        fevVerdict = "INCONCLUSIVE";
        throw new Error(`${step.phase} scale/weight ${posted.status} ${JSON.stringify(posted.json)}`);
      }
    }
    burstElapsedMs = Date.now() - burstStarted;
    p1 = "pass";

    bills = listBills(databasePath, baseline);
    backlogObserved = bills.length === 0;
    if (!backlogObserved) {
      result = "blocked";
      p2 = "blocked";
      fevVerdict = "INCONCLUSIVE";
      detail = `burst finished in ${burstElapsedMs}ms but ${bills.length} weighing row(s) already existed; the queue did not pile up`;
      throw new Error(detail);
    }

    const matches = (bill: Bill, tons: number) =>
      bill.weighingMode === fixture.weighingMode &&
      bill.plate === plate &&
      near(bill.weight, tons, fixture.weightToleranceTons);

    const deadline = Date.now() + fixture.drainWaitMs;
    while (Date.now() < deadline) {
      await sleep(fixture.pollMs);
      bills = listBills(databasePath, baseline);
      waybills = listWaybills(databasePath, waybillBaseline);
      const gross = bills.filter((bill) => matches(bill, fixture.grossTons));
      const tare = bills.filter((bill) => matches(bill, fixture.tareTons));
      const linked = waybills.filter(
        (waybill) => waybill.plate === plate && waybill.weighingMode === fixture.weighingMode,
      );
      const sameWaybill =
        gross.length === 1 &&
        tare.length === 1 &&
        gross[0].waybillId != null &&
        gross[0].waybillId === tare[0].waybillId &&
        linked.some((waybill) => waybill.id === gross[0].waybillId);
      if (bills.length === fixture.expectRecords && sameWaybill && linked.length === fixture.expectWaybills) break;
    }

    bills = listBills(databasePath, baseline);
    waybills = listWaybills(databasePath, waybillBaseline);
    logText = newLogText(logRoot, logBefore);
    const gross = bills.filter((bill) => matches(bill, fixture.grossTons));
    const tare = bills.filter((bill) => matches(bill, fixture.tareTons));
    const linked = waybills.filter(
      (waybill) => waybill.plate === plate && waybill.weighingMode === fixture.weighingMode,
    );
    const ordered =
      bills.length === fixture.expectRecords &&
      gross.length === 1 &&
      tare.length === 1 &&
      bills[0].id === gross[0].id &&
      bills[1].id === tare[0].id;
    const sameWaybill =
      ordered &&
      gross[0].waybillId != null &&
      gross[0].waybillId === tare[0].waybillId &&
      linked.some((waybill) => waybill.id === gross[0].waybillId);

    if (sameWaybill && linked.length === fixture.expectWaybills) {
      p2 = "pass";
      result = "pass";
      fevVerdict = "FEASIBLE";
      detail = `backlog ${burstElapsedMs}ms then waybill ${gross[0].waybillId} plate=${plate} gross=${fixture.grossTons} tare=${fixture.tareTons}`;
    } else if (gross.length >= 1 || tare.length >= 1) {
      p2 = "fail";
      result = "fail";
      fevVerdict = "INFEASIBLE";
      detail = `backlog drained into an unexpected set; bills=${JSON.stringify(bills)} waybills=${JSON.stringify(waybills)}`;
    } else {
      result = "blocked";
      p2 = "blocked";
      fevVerdict = "INCONCLUSIVE";
      detail = `backlog was observed but no weighing row appeared within ${fixture.drainWaitMs}ms. Open the SolidWaste weighing window.`;
    }
  } catch (error) {
    detail = error instanceof Error ? error.message : String(error);
    if (result !== "blocked" && result !== "fail") result = "fail";
    if (fevVerdict === "FEASIBLE") fevVerdict = "INCONCLUSIVE";
  }

  const interesting = logText
    .split(/\r?\n/)
    .filter((line) =>
      /Weight stabilized \(status transition\)|Weight stabilized \(backup check\)|Created weighing record|测试车牌注入成功|地磅测试模式设置重量|TryMatch|ScaleTestWeightPreprocessor/i.test(
        line,
      ),
    )
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
    graphId: GRAPH_ID,
    graphPath: GRAPH_PATH,
    runId: runDir.split(/[\\/]/).at(-1),
    result,
    fevVerdict,
    gitRevision: git,
    levels: { P0: p0, P1: p1, P2: p2, P3: "not-judged" },
    observations: {
      plate,
      grossTons: fixture.grossTons,
      tareTons: fixture.tareTons,
      weighingMode: fixture.weighingMode,
      burstElapsedMs,
      backlogObserved,
      bills,
      waybills,
      detail,
    },
    logLineCount: interesting.length,
  };
  writeText(join(runDir, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
  writeText(
    join(runDir, "report.md"),
    [
      `# ${GRAPH_ID}`,
      "",
      `result: ${result}`,
      `fevVerdict: ${fevVerdict}`,
      `P0: ${p0}`,
      `P1: ${p1}`,
      `P2: ${p2}`,
      "P3: not-judged",
      "",
      `plate: ${plate}`,
      `burstElapsedMs: ${burstElapsedMs}`,
      `backlogObserved: ${backlogObserved}`,
      `bills: ${JSON.stringify(bills)}`,
      `waybills: ${JSON.stringify(waybills)}`,
      `detail: ${detail}`,
      "",
      "This cook does not mean the weighing flow is delivered.",
      "",
    ].join("\n"),
  );
  writeText(
    join(runDir, "manifest.yaml"),
    [
      `graphId: ${GRAPH_ID}`,
      `graphPath: ${GRAPH_PATH}`,
      `runId: ${summary.runId}`,
      `result: ${result}`,
      `gitRevision: "${git}"`,
      `contractPath: ${GRAPH_PATH}/contract.yaml`,
      "artifacts:",
      "  - summary.json",
      "  - report.md",
      "  - manifest.yaml",
      "  - http.json",
      "  - log-excerpt.txt",
      "",
    ].join("\n"),
  );

  console.log(`result=${result} fevVerdict=${fevVerdict} P0=${p0} P1=${p1} P2=${p2}`);
  if (result === "blocked") process.exit(2);
  process.exit(result === "pass" ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
