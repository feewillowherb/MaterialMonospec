/**
 * Experimental FEV probe: drive a running MaterialClient diagnostic host
 * and look for same-callback dual enqueue (status transition + backup) plus
 * ≥2 same-ton WeighingRecords. Does not ProjectReference repos/.
 */
import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";

type Fixture = {
  onScaleTons: number;
  offScaleTons: number;
  weightToleranceTons: number;
  settleMs: number;
  dualRowWaitMs: number;
  pollMs: number;
  expectMinRows: number;
  logNeedles: string[];
};

type Bill = {
  id: number;
  plate: string;
  weight: number;
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
        `SELECT Id AS id, COALESCE(PlateNumber, '') AS plate, TotalWeight AS weight
         FROM WeighingRecords
         WHERE Id > ?
         ORDER BY Id ASC`,
      )
      .all(afterId) as Array<{ id: number | bigint; plate: string; weight: number }>;
    return rows.map((row) => ({
      id: Number(row.id),
      plate: row.plate,
      weight: Number(row.weight),
    }));
  });
}

function snapshotLogs(logRoot: string): Map<string, number> {
  const map = new Map<string, number>();
  if (!statSync(logRoot, { throwIfNoEntry: false })?.isDirectory()) return map;
  for (const name of readdirSync(logRoot)) {
    const full = join(logRoot, name);
    const st = statSync(full, { throwIfNoEntry: false });
    if (st?.isFile()) map.set(name, st.size);
  }
  return map;
}

function newLogText(logRoot: string, before: Map<string, number>): string {
  if (!statSync(logRoot, { throwIfNoEntry: false })?.isDirectory()) return "";
  const chunks: string[] = [];
  for (const name of readdirSync(logRoot).sort()) {
    const full = join(logRoot, name);
    const st = statSync(full, { throwIfNoEntry: false });
    if (!st?.isFile()) continue;
    const prev = before.get(name) ?? 0;
    if (st.size <= prev) continue;
    const buf = readFileSync(full);
    chunks.push(buf.subarray(prev).toString("utf8"));
  }
  return chunks.join("\n");
}

function near(a: number, b: number, tol: number): boolean {
  return Math.abs(a - b) <= tol;
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
  let logText = "";
  let statusTransition = false;
  let backupCheck = false;
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
        `Diagnostic host is not reachable at ${baseUrl}. Start scripts/MaterialClient/Start-MaterialClient.ps1 -EnableDiagnosticHost, login, open attended weighing. ${String(error)}`,
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
        `prelude scale/weight ${offPrelude.status} ${JSON.stringify(offPrelude.json)}. Need ScaleType=TestMode(2) and attended weighing running.`,
      );
    }
    await sleep(fixture.settleMs);

    const baseline = maxId(databasePath);
    const plate = `FEV${Date.now().toString(36).toUpperCase()}`;
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

    const deadline = Date.now() + fixture.dualRowWaitMs;
    while (Date.now() < deadline) {
      await sleep(fixture.pollMs);
      bills = listBills(databasePath, baseline);
      logText = newLogText(logRoot, logBefore);
      statusTransition = logText.includes("Weight stabilized (status transition)");
      backupCheck = logText.includes("Weight stabilized (backup check)");
      const sameTon = bills.filter((b) => near(b.weight, fixture.onScaleTons, fixture.weightToleranceTons));
      if (statusTransition && backupCheck && sameTon.length >= fixture.expectMinRows) {
        break;
      }
    }

    bills = listBills(databasePath, baseline);
    logText = newLogText(logRoot, logBefore);
    statusTransition = logText.includes("Weight stabilized (status transition)");
    backupCheck = logText.includes("Weight stabilized (backup check)");
    const sameTon = bills.filter((b) => near(b.weight, fixture.onScaleTons, fixture.weightToleranceTons));
    const dualLog = statusTransition && backupCheck;
    const dualRow = sameTon.length >= fixture.expectMinRows;

    if (dualLog && dualRow) {
      p2 = "pass";
      result = "pass";
      fevVerdict = "FEASIBLE";
      detail = `dual log + ${sameTon.length} same-ton rows for plate=${plate}`;
    } else if (p1 === "pass") {
      p2 = "fail";
      result = "fail";
      fevVerdict = "INFEASIBLE";
      detail = `statusTransition=${statusTransition} backupCheck=${backupCheck} sameTonRows=${sameTon.length} bills=${JSON.stringify(bills)}`;
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
      /Weight stabilized \(status transition\)|Weight stabilized \(backup check\)|Created weighing record|Test plate injected|地磅测试模式设置重量|Scale test weight/i.test(
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
    graphId: "fev-stable-dual-enqueue-repro",
    graphPath: "pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro",
    runId: runDir.split(/[\\/]/).at(-1),
    result,
    fevVerdict,
    gitRevision: git,
    levels: { P0: p0, P1: p1, P2: p2, P3: "not-judged" },
    observations: {
      statusTransition,
      backupCheck,
      bills,
      detail,
    },
    logLineCount: interesting.length,
  };
  writeText(join(runDir, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
  writeText(
    join(runDir, "report.md"),
    [
      "# fev-stable-dual-enqueue-repro",
      "",
      `result: ${result}`,
      `fevVerdict: ${fevVerdict}`,
      `P0: ${p0}`,
      `P1: ${p1}`,
      `P2: ${p2}`,
      "P3: not-judged",
      "",
      `statusTransition: ${statusTransition}`,
      `backupCheck: ${backupCheck}`,
      `bills: ${JSON.stringify(bills)}`,
      `detail: ${detail}`,
      "",
      "This cook does not mean the product fix shipped.",
      "",
    ].join("\n"),
  );
  writeText(
    join(runDir, "manifest.yaml"),
    [
      "graphId: fev-stable-dual-enqueue-repro",
      "graphPath: pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro",
      `runId: ${summary.runId}`,
      `result: ${result}`,
      `gitRevision: "${git}"`,
      "contractPath: pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/contract.yaml",
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
