/**
 * Experimental FEV probe: drive a running MaterialClient.SolidWaste diagnostic host.
 * Inject one test plate and one stable test-scale weight, then look for a new
 * WeighingRecords row with WeighingMode = SolidWaste. Does not ProjectReference repos/.
 * Does not read or store an activation code.
 */
import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { DatabaseSync } from "node:sqlite";

type Fixture = {
  onScaleTons: number;
  offScaleTons: number;
  weightToleranceTons: number;
  weighingMode: number;
  offScaleSettleMs: number;
  rowWaitMs: number;
  pollMs: number;
  expectMinRows: number;
};

type Bill = {
  id: number;
  plate: string;
  weight: number;
  weighingMode: number;
};

const GRAPH_ID = "fev-solidwaste-weigh-lpr";
const GRAPH_PATH = "pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr";

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
): Promise<{ status: number; json: unknown }> {
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

function maxId(databasePath: string): number {
  return withDb(databasePath, (db) => {
    const row = db.prepare("SELECT COALESCE(MAX(Id), 0) AS maxId FROM WeighingRecords").get() as {
      maxId: number | bigint;
    };
    return Number(row.maxId);
  });
}

function listBills(databasePath: string, afterId: number): Bill[] {
  return withDb(databasePath, (db) => {
    const rows = db
      .prepare(
        `SELECT Id AS id, COALESCE(PlateNumber, '') AS plate, TotalWeight AS weight, WeighingMode AS weighingMode
         FROM WeighingRecords
         WHERE Id > ?
         ORDER BY Id ASC`,
      )
      .all(afterId) as Array<{
      id: number | bigint;
      plate: string;
      weight: number;
      weighingMode: number | bigint;
    }>;
    return rows.map((row) => ({
      id: Number(row.id),
      plate: row.plate,
      weight: Number(row.weight),
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
  let matched: Bill[] = [];
  let logText = "";
  let plate = "";
  let stabilized = false;
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
        `Diagnostic host is not reachable at ${baseUrl}. Start scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost. If an activation window is open, the user enters the code. Hikvision LPR skips this host. ${String(error)}`,
      );
    }
    recordHttp({ path: "/", status: root.status });
    if (root.status !== 200) {
      result = "blocked";
      p0 = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(`GET / returned ${root.status}`);
    }
    p0 = "pass";

    const offPrelude = await requestJson(baseUrl, "/api/scale/weight", "POST", {
      weight: fixture.offScaleTons,
    });
    recordHttp({
      path: "/api/scale/weight",
      status: offPrelude.status,
      weight: fixture.offScaleTons,
      prelude: true,
      body: offPrelude.json,
    });
    if (offPrelude.status !== 200) {
      result = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(
        `prelude scale/weight ${offPrelude.status} ${JSON.stringify(offPrelude.json)}. Need ScaleType=TestMode and the SolidWaste weighing window.`,
      );
    }
    await sleep(fixture.offScaleSettleMs);

    const baseline = maxId(databasePath);
    plate = makePlate();
    const platePosted = await requestJson(baseUrl, "/api/lpr/test-plate", "POST", {
      plateNumber: plate,
    });
    recordHttp({ path: "/api/lpr/test-plate", status: platePosted.status, plate, body: platePosted.json });
    if (platePosted.status !== 200) {
      result = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(`test-plate ${platePosted.status} ${JSON.stringify(platePosted.json)}`);
    }

    const onPosted = await requestJson(baseUrl, "/api/scale/weight", "POST", {
      weight: fixture.onScaleTons,
    });
    recordHttp({
      path: "/api/scale/weight",
      status: onPosted.status,
      weight: fixture.onScaleTons,
      body: onPosted.json,
    });
    if (onPosted.status !== 200) {
      result = "blocked";
      fevVerdict = "INCONCLUSIVE";
      throw new Error(`scale/weight ${onPosted.status} ${JSON.stringify(onPosted.json)}`);
    }
    p1 = "pass";

    const deadline = Date.now() + fixture.rowWaitMs;
    while (Date.now() < deadline) {
      await sleep(fixture.pollMs);
      bills = listBills(databasePath, baseline);
      logText = newLogText(logRoot, logBefore);
      stabilized = logText.includes("Weight stabilized (status transition)");
      matched = bills.filter(
        (bill) =>
          bill.weighingMode === fixture.weighingMode &&
          bill.plate === plate &&
          near(bill.weight, fixture.onScaleTons, fixture.weightToleranceTons),
      );
      if (matched.length >= fixture.expectMinRows) break;
    }

    bills = listBills(databasePath, baseline);
    logText = newLogText(logRoot, logBefore);
    stabilized = logText.includes("Weight stabilized (status transition)");
    matched = bills.filter(
      (bill) =>
        bill.weighingMode === fixture.weighingMode &&
        bill.plate === plate &&
        near(bill.weight, fixture.onScaleTons, fixture.weightToleranceTons),
    );

    if (matched.length >= fixture.expectMinRows) {
      p2 = "pass";
      result = "pass";
      fevVerdict = "FEASIBLE";
      detail = `matched ${matched.length} SolidWaste row(s) plate=${plate} weight=${fixture.onScaleTons}`;
    } else if (p1 === "pass" && stabilized) {
      p2 = "fail";
      result = "fail";
      fevVerdict = "INFEASIBLE";
      detail = `stabilized but no matching WeighingMode=${fixture.weighingMode} row; bills=${JSON.stringify(bills)}`;
    } else {
      result = "blocked";
      p2 = "blocked";
      fevVerdict = "INCONCLUSIVE";
      detail = `inject succeeded but weighing did not stabilize. Open the SolidWaste weighing window after the user activates and logs in. bills=${JSON.stringify(bills)}`;
    }

    const off = await requestJson(baseUrl, "/api/scale/weight", "POST", {
      weight: fixture.offScaleTons,
    });
    recordHttp({
      path: "/api/scale/weight",
      status: off.status,
      weight: fixture.offScaleTons,
      cleanup: true,
      body: off.json,
    });
  } catch (error) {
    detail = error instanceof Error ? error.message : String(error);
    if (result !== "blocked") result = "fail";
    if (fevVerdict === "FEASIBLE") fevVerdict = "INCONCLUSIVE";
  }

  const interesting = logText
    .split(/\r?\n/)
    .filter((line) =>
      /Weight stabilized \(status transition\)|Created weighing record|测试车牌注入成功|地磅测试模式设置重量/i.test(line),
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
      onScaleTons: fixture.onScaleTons,
      weighingMode: fixture.weighingMode,
      stabilized,
      matched,
      bills,
      detail,
    },
    logLineCount: interesting.length,
  };
  writeText(join(runDir, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
  writeText(
    join(runDir, "report.md"),
    [
      "# fev-solidwaste-weigh-lpr",
      "",
      `result: ${result}`,
      `fevVerdict: ${fevVerdict}`,
      `P0: ${p0}`,
      `P1: ${p1}`,
      `P2: ${p2}`,
      "P3: not-judged",
      "",
      `plate: ${plate}`,
      `stabilized: ${stabilized}`,
      `matched: ${JSON.stringify(matched)}`,
      `bills: ${JSON.stringify(bills)}`,
      `detail: ${detail}`,
      "",
      "This cook does not mean the SolidWaste weighing flow is delivered.",
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
