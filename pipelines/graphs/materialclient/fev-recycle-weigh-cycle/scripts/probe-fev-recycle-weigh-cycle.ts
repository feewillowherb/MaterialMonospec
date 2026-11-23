/**
 * Experimental FEV probe: drive a running MaterialClient.Recycle diagnostic host.
 * Plate text comes from /api/lpr/test-plate with no image. The photo comes from LPR trigger.
 * Each case ascends to the target tons, waits for the record and LPR file, then descends to 0.
 * Does not ProjectReference repos/. Does not write the database or stop the client.
 */
import { execSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { DatabaseSync } from "node:sqlite";

type CaseFixture = {
  plate: string;
  grossTons: number;
};

type Fixture = {
  offScaleTons: number;
  weightToleranceTons: number;
  weighingMode: number;
  plateRepeats: number;
  holdRepostMs: number;
  ascentWaitMs: number;
  lprWaitMs: number;
  departureWaitMs: number;
  receiveWaitMs: number;
  cases: CaseFixture[];
};

type AttachmentHit = {
  attachType: number;
  localPath: string;
  bytes: number;
};

type RecordHit = {
  id: number;
  plate: string;
  weight: number;
  weighingMode: number;
  waybillId: number | null;
  receiveState: string | null;
  attachments: AttachmentHit[];
};

const GRAPH_ID = "fev-recycle-weigh-cycle";
const GRAPH_PATH = "pipelines/graphs/materialclient/fev-recycle-weigh-cycle";
const LPR_ATTACH_TYPE = 5;

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
  const db = new DatabaseSync(databasePath, { readOnly: true, timeout: 8000 });
  try {
    return read(db);
  } finally {
    db.close();
  }
}

function readHostFlags(databasePath: string): { scaleType: number | null; trigger: boolean | null } {
  return withDb(databasePath, (db) => {
    const row = db.prepare("SELECT ScaleSettingsJson AS scale, SystemSettingsJson AS system FROM Settings LIMIT 1").get() as {
      scale: string;
      system: string;
    };
    const scale = JSON.parse(row.scale) as { ScaleType?: number; scaleType?: number };
    const system = JSON.parse(row.system) as { EnableTriggerLprCapture?: boolean; enableTriggerLprCapture?: boolean };
    return {
      scaleType: scale.ScaleType ?? scale.scaleType ?? null,
      trigger: system.EnableTriggerLprCapture ?? system.enableTriggerLprCapture ?? null,
    };
  });
}

function maxId(databasePath: string): number {
  return withDb(databasePath, (db) => {
    const row = db.prepare("SELECT COALESCE(MAX(Id), 0) AS maxId FROM WeighingRecords").get() as {
      maxId: number | bigint;
    };
    return Number(row.maxId);
  });
}

function maxWaybillId(databasePath: string): number {
  return withDb(databasePath, (db) => {
    const row = db.prepare("SELECT COALESCE(MAX(Id), 0) AS maxId FROM Waybills").get() as {
      maxId: number | bigint;
    };
    return Number(row.maxId);
  });
}

function receiveState(extra: string | null): string | null {
  if (!extra) return null;
  try {
    const parsed = JSON.parse(extra) as { RecycleWebReceiveState?: string };
    return parsed.RecycleWebReceiveState ?? null;
  } catch {
    return null;
  }
}

function listRecords(databasePath: string, dataRoot: string, afterId: number): RecordHit[] {
  return withDb(databasePath, (db) => {
    const rows = db
      .prepare(
        `SELECT Id AS id, COALESCE(PlateNumber, '') AS plate, TotalWeight AS weight,
                WeighingMode AS weighingMode, WaybillId AS waybillId, ExtraProperties AS extra
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
      extra: string | null;
    }>;
    return rows.map((row) => {
      const id = Number(row.id);
      const files = db
        .prepare(
          `SELECT af.AttachType AS attachType, af.LocalPath AS localPath
           FROM WeighingRecordAttachments link
           JOIN AttachmentFiles af ON af.Id = link.AttachmentFileId
           WHERE link.WeighingRecordId = ? AND IFNULL(af.IsDeleted, 0) = 0`,
        )
        .all(id) as Array<{ attachType: number | bigint; localPath: string }>;
      const attachments = files.map((file) => {
        const localPath = file.localPath ?? "";
        const full = localPath.startsWith("\\\\") || /^[A-Za-z]:/.test(localPath) ? localPath : join(dataRoot, localPath);
        const st = statSync(full, { throwIfNoEntry: false });
        return {
          attachType: Number(file.attachType),
          localPath,
          bytes: st?.isFile() ? st.size : 0,
        };
      });
      return {
        id,
        plate: row.plate,
        weight: Number(row.weight),
        weighingMode: Number(row.weighingMode),
        waybillId: row.waybillId == null ? null : Number(row.waybillId),
        receiveState: receiveState(row.extra),
        attachments,
      };
    });
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
      chunks.push(readFileSync(full).subarray(prev).toString("utf8"));
    }
  };
  walk(logRoot);
  return chunks.join("\n");
}

function near(a: number, b: number, tol: number): boolean {
  return Math.abs(a - b) <= tol;
}

function hasLpr(record: RecordHit): boolean {
  return record.attachments.some((file) => file.attachType === LPR_ATTACH_TYPE && file.bytes > 0);
}

function redact(text: string): string {
  return text.replace(/eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[redacted]");
}

async function main() {
  const runDir = mustArg("--run");
  const baseUrl = mustArg("--baseUrl").replace(/\/$/, "");
  const databasePath = mustArg("--database");
  const logRoot = mustArg("--log");
  const fixturePath = mustArg("--fixture");
  const repoRoot = mustArg("--repo");
  const fixture = readJson<Fixture>(fixturePath);
  const dataRoot = dirname(databasePath);

  const httpLog: unknown[] = [];
  let result: "pass" | "fail" | "blocked" = "fail";
  let p0 = "fail";
  let p1 = "fail";
  let p2 = "fail";
  let fevVerdict: "FEASIBLE" | "INFEASIBLE" | "INCONCLUSIVE" = "INCONCLUSIVE";
  let detail = "";
  let logText = "";
  const cases: unknown[] = [];
  const logBefore = snapshotLogs(logRoot);

  const recordHttp = (entry: unknown) => {
    httpLog.push(entry);
  };

  const postWeight = async (tons: number, phase: string) => {
    const posted = await requestJson(baseUrl, "/api/scale/weight", "POST", { weight: tons });
    recordHttp({ path: "/api/scale/weight", status: posted.status, weight: tons, phase, body: posted.json });
    if (posted.status !== 200) {
      throw new Error(`scale/weight ${posted.status} ${JSON.stringify(posted.json)} phase=${phase}`);
    }
  };

  const postPlate = async (plate: string) => {
    const body = { plateNumber: plate };
    const posted = await requestJson(baseUrl, "/api/lpr/test-plate", "POST", body);
    recordHttp({
      path: "/api/lpr/test-plate",
      status: posted.status,
      plate,
      bodyKeys: Object.keys(body),
      hasImage: false,
      body: posted.json,
    });
    if (posted.status !== 200) {
      throw new Error(`test-plate ${posted.status} ${JSON.stringify(posted.json)}`);
    }
  };

  try {
    let root: { status: number; json: unknown };
    try {
      root = await requestJson(baseUrl, "/", "GET");
    } catch (error) {
      result = "blocked";
      p0 = "blocked";
      throw new Error(`Diagnostic host is not reachable at ${baseUrl}. ${String(error)}`);
    }
    recordHttp({ path: "/", status: root.status });
    if (root.status !== 200) {
      result = "blocked";
      p0 = "blocked";
      throw new Error(`GET / returned ${root.status}`);
    }

    const flags = readHostFlags(databasePath);
    recordHttp({ scaleType: flags.scaleType, triggerLpr: flags.trigger });
    if (flags.scaleType !== 2 || flags.trigger !== true) {
      result = "blocked";
      p0 = "blocked";
      throw new Error(`Need ScaleType=2 and EnableTriggerLprCapture=true. Observed scaleType=${flags.scaleType} trigger=${flags.trigger}`);
    }
    p0 = "pass";

    await postWeight(fixture.offScaleTons, "prelude");
    await sleep(2000);
    const baseline = maxId(databasePath);
    const waybillBaseline = maxWaybillId(databasePath);

    for (const item of fixture.cases) {
      for (let i = 0; i < fixture.plateRepeats; i += 1) {
        await postPlate(item.plate);
        p1 = "pass";
        await sleep(150);
      }

      const started = Date.now();
      let lastHigh = 0;
      let ready: RecordHit | undefined;
      while (Date.now() - started < fixture.ascentWaitMs) {
        if (Date.now() - lastHigh >= fixture.holdRepostMs) {
          await postWeight(item.grossTons, "ascent");
          lastHigh = Date.now();
        }
        await sleep(1000);
        const records = listRecords(databasePath, dataRoot, baseline);
        ready = records.find(
          (record) =>
            record.weighingMode === fixture.weighingMode &&
            record.plate === item.plate &&
            near(record.weight, item.grossTons, fixture.weightToleranceTons) &&
            hasLpr(record),
        );
        if (ready) break;
      }

      if (!ready) {
        const records = listRecords(databasePath, dataRoot, baseline);
        const partial = records.find(
          (record) =>
            record.weighingMode === fixture.weighingMode &&
            record.plate === item.plate &&
            near(record.weight, item.grossTons, fixture.weightToleranceTons),
        );
        cases.push({ plate: item.plate, grossTons: item.grossTons, record: partial ?? null, departed: false });
        if (partial) {
          result = "fail";
          p2 = "fail";
          fevVerdict = "INFEASIBLE";
          throw new Error(`record ${partial.id} for ${item.plate} has no LPR file`);
        }
        result = "blocked";
        p2 = "blocked";
        throw new Error(`no recycle row for ${item.plate} at ${item.grossTons}t`);
      }

      const drainMs = Math.max(0, 6000 - (Date.now() - lastHigh));
      await sleep(drainMs);
      await postWeight(fixture.offScaleTons, "departure");
      await sleep(2000);
      await postWeight(fixture.offScaleTons, "departure-hold");

      const departStart = Date.now();
      let departed = false;
      while (Date.now() - departStart < fixture.departureWaitMs) {
        await sleep(1000);
        logText = newLogText(logRoot, logBefore);
        const slice = logText.slice(logText.lastIndexOf(`测试车牌注入成功：Plate=${item.plate}`));
        if (slice.includes("Normal flow completed")) {
          departed = true;
          break;
        }
        if (slice.includes("Abnormal departure") || slice.includes("Unstable weighing flow")) {
          result = "fail";
          p2 = "fail";
          fevVerdict = "INFEASIBLE";
          throw new Error(`${item.plate} left the scale before a normal departure`);
        }
      }
      if (!departed) {
        result = "blocked";
        p2 = "blocked";
        throw new Error(`${item.plate} did not log a normal departure`);
      }

      const receiveStart = Date.now();
      let current = ready;
      while (Date.now() - receiveStart < fixture.receiveWaitMs) {
        await sleep(1000);
        const records = listRecords(databasePath, dataRoot, baseline);
        current = records.find((record) => record.id === ready?.id) ?? current;
        if (current.receiveState === "Pending" || current.receiveState === "Accepted") break;
      }
      const waybillsAfter = maxWaybillId(databasePath);
      cases.push({
        plate: item.plate,
        grossTons: item.grossTons,
        recordId: current.id,
        weight: current.weight,
        waybillId: current.waybillId,
        receiveState: current.receiveState,
        lprBytes: current.attachments.filter((file) => file.attachType === LPR_ATTACH_TYPE).map((file) => file.bytes),
        departed: true,
        newWaybills: waybillsAfter - waybillBaseline,
      });
      if (current.waybillId != null || waybillsAfter > waybillBaseline) {
        result = "fail";
        p2 = "fail";
        fevVerdict = "INFEASIBLE";
        throw new Error(`${item.plate} created a waybill`);
      }
      if (current.receiveState !== "Pending" && current.receiveState !== "Accepted") {
        result = "fail";
        p2 = "fail";
        fevVerdict = "INFEASIBLE";
        throw new Error(`${item.plate} record ${current.id} finished the cycle without RecycleWebReceiveState`);
      }
      if (!hasLpr(current)) {
        result = "fail";
        p2 = "fail";
        fevVerdict = "INFEASIBLE";
        throw new Error(`${item.plate} lost its LPR file before departure`);
      }
    }

    logText = newLogText(logRoot, logBefore);
    if (logText.includes("LPR 主动抓拍已禁用")) {
      result = "fail";
      p2 = "fail";
      fevVerdict = "INFEASIBLE";
      throw new Error("LPR trigger was disabled during the run");
    }

    p2 = "pass";
    result = "pass";
    fevVerdict = "FEASIBLE";
    detail = cases.map((item) => JSON.stringify(item)).join("; ");
  } catch (error) {
    detail = error instanceof Error ? error.message : String(error);
    if (result !== "blocked" && result !== "fail") result = "fail";
    if (fevVerdict === "FEASIBLE") fevVerdict = "INCONCLUSIVE";
    if (fevVerdict === "INCONCLUSIVE" && result === "fail") fevVerdict = "INFEASIBLE";
  }

  logText = newLogText(logRoot, logBefore);
  const interesting = redact(logText)
    .split(/\r?\n/)
    .filter((line) =>
      /测试车牌注入成功|地磅测试模式设置重量|Weight stabilized|Normal flow completed|Abnormal departure|Unstable weighing|Hikvision LPR|抓拍已发送|Queued recycle weigh|LPR 主动抓拍|Recycle web receive|401/.test(
        line,
      ),
    )
    .slice(-240);
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
    clientLeftRunning: true,
    observations: { cases, detail },
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
      "The Recycle client is left running.",
      `cases: ${JSON.stringify(cases)}`,
      `detail: ${detail}`,
      "",
      "This cook does not mean the recycle upload is delivered.",
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
  console.log(detail);
  if (result === "blocked") process.exit(2);
  process.exit(result === "pass" ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
