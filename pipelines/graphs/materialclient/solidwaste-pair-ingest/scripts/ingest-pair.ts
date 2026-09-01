#!/usr/bin/env node
/**
 * Experimental: backfill missing SolidWaste join weighing + pair Waybill.
 * Uses Node >= 22.5 built-in node:sqlite. ASCII-safe source.
 */
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

type Scenario = {
  plateNumber: string;
  joinWeightTon: string;
  outWeightTon: string;
  netWeightTon: string;
  joinTime: string;
  outRecordId?: number;
  deliveryType: number;
  weighingMode: number;
  orderSource: number;
  orderType: number;
  isPendingSync: boolean;
  imageGlobs: string[];
  imageFiles?: string[];
  photoRelDir?: string;
  dryRun: boolean;
};

type Paths = {
  databasePath: string;
  sourceDir: string;
  photoRoot: string;
  runDir: string;
};

const AttachType = {
  UnmatchedEntryPhoto: 0,
  EntryPhoto: 1,
  ExitPhoto: 2,
} as const;

const MatchType = { Join: 0, Out: 1 } as const;

function usage(): never {
  console.error(
    "Usage: ingest-pair --database <path> --sourceDir <path> --photoRoot <path> --runDir <path> --scenarioJson <path> [--write]",
  );
  process.exit(1);
}

function parseArgs(argv: string[]): {
  database?: string;
  sourceDir?: string;
  photoRoot?: string;
  runDir?: string;
  scenarioJson?: string;
  write: boolean;
} {
  const out: ReturnType<typeof parseArgs> = { write: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      const v = argv[++i];
      if (!v) usage();
      return v;
    };
    if (a === "--database") out.database = next();
    else if (a === "--sourceDir") out.sourceDir = next();
    else if (a === "--photoRoot") out.photoRoot = next();
    else if (a === "--runDir") out.runDir = next();
    else if (a === "--scenarioJson") out.scenarioJson = next();
    else if (a === "--write") out.write = true;
    else if (a === "--help" || a === "-h") usage();
  }
  return out;
}

function pad2(n: number): string {
  return n.toString().padStart(2, "0");
}

/** EF-style local datetime string (no timezone). */
function formatEfDateTime(date: Date): string {
  const frac = `${date.getMilliseconds().toString().padStart(3, "0")}0000`;
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(date.getSeconds())}.${frac}`;
}

function parseLocalDateTime(text: string): Date {
  const m = text.trim().match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})/);
  if (!m) throw new Error(`Invalid datetime: ${text}`);
  const d = new Date(
    Number(m[1]),
    Number(m[2]) - 1,
    Number(m[3]),
    Number(m[4]),
    Number(m[5]),
    Number(m[6]),
    0,
  );
  if (Number.isNaN(d.getTime())) throw new Error(`Invalid datetime: ${text}`);
  return d;
}

function toUnixSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000);
}

function dec(a: string): number {
  return Number(a);
}

function almostEqual(a: number, b: number, eps = 0.001): boolean {
  return Math.abs(a - b) <= eps;
}

const GUID_FILE_RE = /^.+_1_[0-9a-f]{32}\.jpe?g$/i;

function resolveImageFiles(sourceDir: string, names: string[]): string[] {
  const resolved: string[] = [];
  for (const want of names) {
    const normalized = want.replace(/\//g, "\\");
    const abs = resolve(sourceDir, normalized);
    if (!existsSync(abs)) {
      throw new Error(`Missing image '${want}' -> ${abs}`);
    }
    const fileName = basename(abs);
    if (!GUID_FILE_RE.test(fileName)) {
      throw new Error(
        `Image name must match '{camera}_1_{guid32}.jpg' (existing AttachmentFiles style). Got: ${fileName}`,
      );
    }
    resolved.push(abs);
  }
  return resolved;
}

/** Fixed relative LocalPath: PhotoJianKong\YYYY\MM\DD\file.jpg */
function toLocalPath(photoRelDir: string, fileName: string): string {
  const dir = photoRelDir.replace(/\//g, "\\").replace(/\\+$/, "");
  return `${dir}\\${fileName}`;
}

function nextWaybillId(existingIds: Set<string>): bigint {
  let id: bigint;
  do {
    const ms = BigInt(Date.now());
    const rand = BigInt(Math.floor(Math.random() * 0x3fffff));
    id = (ms << 22n) | rand;
  } while (existingIds.has(id.toString()));
  return id;
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2), "utf8");
}

async function main(): Promise<void> {
  const { DatabaseSync } = await import("node:sqlite");
  const args = parseArgs(process.argv.slice(2));
  if (!args.database || !args.sourceDir || !args.photoRoot || !args.runDir || !args.scenarioJson) {
    usage();
  }

  const scenario = JSON.parse(readFileSync(args.scenarioJson, "utf8")) as Scenario;
  // --write wins; otherwise honor scenario.dryRun (default true)
  const willWrite = Boolean(args.write) || scenario.dryRun === false;

  const paths: Paths = {
    databasePath: resolve(args.database),
    sourceDir: resolve(args.sourceDir),
    photoRoot: resolve(args.photoRoot),
    runDir: resolve(args.runDir),
  };

  mkdirSync(paths.runDir, { recursive: true });
  const prepareDir = join(paths.runDir, "prepare");
  mkdirSync(prepareDir, { recursive: true });

  if (!existsSync(paths.databasePath)) {
    throw new Error(`Database not found: ${paths.databasePath}`);
  }

  const joinAt = parseLocalDateTime(scenario.joinTime);
  const imageNames = scenario.imageFiles?.length
    ? scenario.imageFiles
    : scenario.imageGlobs;
  if (!imageNames?.length) {
    throw new Error("scenario.imageFiles (or imageGlobs) is required");
  }
  const images = resolveImageFiles(paths.sourceDir, imageNames);
  const photoRelDir = (scenario.photoRelDir?.trim() || "PhotoJianKong\\2026\\09\\01").replace(
    /\//g,
    "\\",
  );
  if (!/^PhotoJianKong\\2026\\09\\01$/i.test(photoRelDir)) {
    throw new Error(`photoRelDir must be PhotoJianKong\\2026\\09\\01, got: ${photoRelDir}`);
  }
  const joinWeight = dec(scenario.joinWeightTon);
  const outWeight = dec(scenario.outWeightTon);
  const netWeight = dec(scenario.netWeightTon);
  if (!almostEqual(joinWeight - outWeight, netWeight)) {
    throw new Error(
      `Weight integrity failed: join(${joinWeight}) - out(${outWeight}) != net(${netWeight})`,
    );
  }

  const db = new DatabaseSync(paths.databasePath);
  db.exec("PRAGMA foreign_keys = OFF;");

  const outRow = scenario.outRecordId
    ? db.prepare("SELECT * FROM WeighingRecords WHERE Id = ?").get(scenario.outRecordId)
    : db
        .prepare(
          `SELECT * FROM WeighingRecords
           WHERE PlateNumber = ? AND IsDeleted = 0 AND MatchedId IS NULL
             AND CAST(TotalWeight AS REAL) = ?
           ORDER BY AddDate ASC LIMIT 1`,
        )
        .get(scenario.plateNumber, outWeight);

  writeJson(join(prepareDir, "locate-out.json"), {
    query: { outRecordId: scenario.outRecordId ?? null, plate: scenario.plateNumber, outWeight },
    found: outRow ?? null,
  });

  if (!outRow) {
    writeSummary(paths.runDir, {
      dryRun: !willWrite,
      L0: "pass",
      L1: "fail",
      L2: "fail",
      error: "Unmatched out weighing record not found",
    });
    console.error("L1 fail: unmatched out record not found");
    process.exit(1);
  }

  const outId = Number((outRow as { Id: number }).Id);
  const outMatchedId = (outRow as { MatchedId: number | null }).MatchedId;
  const outPlate = String((outRow as { PlateNumber: string }).PlateNumber);
  const outTotal = dec(String((outRow as { TotalWeight: string }).TotalWeight));
  const outAddDate = String((outRow as { AddDate: string }).AddDate);
  const creatorId = (outRow as { CreateUserId: number | null }).CreateUserId ?? 3405;
  const creator = (outRow as { Creator: string | null }).Creator ?? "ingest-pair";

  if (outPlate !== scenario.plateNumber) {
    throw new Error(`Plate mismatch: out=${outPlate} scenario=${scenario.plateNumber}`);
  }
  if (!almostEqual(outTotal, outWeight)) {
    throw new Error(`Out weight mismatch: db=${outTotal} scenario=${outWeight}`);
  }

  // Idempotent success if already paired correctly
  if (outMatchedId != null) {
    const joinExisting = db.prepare("SELECT * FROM WeighingRecords WHERE Id = ?").get(outMatchedId) as
      | Record<string, unknown>
      | undefined;
    const waybillId = (outRow as { WaybillId: number | null }).WaybillId;
    const wb = waybillId
      ? (db.prepare("SELECT * FROM Waybills WHERE Id = ?").get(waybillId) as Record<string, unknown> | undefined)
      : undefined;
    const ok =
      joinExisting &&
      almostEqual(dec(String(joinExisting.TotalWeight)), joinWeight) &&
      String(joinExisting.AddDate).startsWith(scenario.joinTime.slice(0, 19)) &&
      wb &&
      almostEqual(dec(String(wb.OrderTotalWeight)), joinWeight) &&
      almostEqual(dec(String(wb.OrderTruckWeight)), outWeight) &&
      almostEqual(dec(String(wb.OrderGoodsWeight)), netWeight);

    writeJson(join(prepareDir, "idempotent.json"), { outId, outMatchedId, waybillId, ok });
    writeSummary(paths.runDir, {
      dryRun: !willWrite,
      L0: "pass",
      L1: "pass",
      L2: ok ? "pass" : "fail",
      skipped: true,
      outRecordId: outId,
      joinRecordId: outMatchedId,
      waybillId,
      message: ok ? "Already paired with matching weights/time" : "Already matched but weights/time mismatch",
    });
    console.log(ok ? "Idempotent skip: already paired OK" : "Already matched but integrity mismatch");
    process.exit(ok ? 0 : 1);
  }

  const outAt = parseLocalDateTime(outAddDate);
  const minutes = Math.abs(joinAt.getTime() - outAt.getTime()) / 60000;
  if (minutes > 300) {
    throw new Error(`Join/out interval ${minutes.toFixed(1)}min exceeds 300`);
  }
  if (joinAt >= outAt) {
    throw new Error(`Join time must be before out time (${scenario.joinTime} < ${outAddDate})`);
  }
  if (joinWeight <= outWeight) {
    throw new Error("Receiving requires join weight > out weight");
  }

  const plan = {
    willWrite,
    plateNumber: scenario.plateNumber,
    join: {
      totalWeight: scenario.joinWeightTon,
      addDate: formatEfDateTime(joinAt),
      addTime: toUnixSeconds(joinAt),
      matchedType: MatchType.Join,
    },
    out: {
      id: outId,
      totalWeight: scenario.outWeightTon,
      addDate: outAddDate,
      matchedType: MatchType.Out,
    },
    waybill: {
      orderTotalWeight: scenario.joinWeightTon,
      orderTruckWeight: scenario.outWeightTon,
      orderGoodsWeight: scenario.netWeightTon,
      deliveryType: scenario.deliveryType,
      weighingMode: scenario.weighingMode,
      orderSource: scenario.orderSource,
      orderType: scenario.orderType,
      isPendingSync: scenario.isPendingSync ? 1 : 0,
    },
    images: images.map((p) => basename(p)),
  };
  writeJson(join(prepareDir, "plan.json"), plan);

  if (!willWrite) {
    writeSummary(paths.runDir, {
      dryRun: true,
      L0: "pass",
      L1: "pass",
      L2: "pending-write",
      message: "dryRun: no DB writes. Re-run with --write / dryRun:false",
      plan,
    });
    console.log("dryRun complete. Pass --write to apply.");
    process.exit(0);
  }

  const joinText = formatEfDateTime(joinAt);
  const joinUnix = toUnixSeconds(joinAt);
  const now = new Date();
  const nowText = formatEfDateTime(now);
  const nowUnix = toUnixSeconds(now);
  const dayPrefix = `${joinAt.getFullYear()}-${pad2(joinAt.getMonth() + 1)}-${pad2(joinAt.getDate())}`;
  const todayCount =
    (
      db
        .prepare("SELECT COUNT(*) AS c FROM Waybills WHERE AddDate LIKE ?")
        .get(`${dayPrefix}%`) as { c: number }
    ).c + 1;
  const orderNo = `sl-${joinAt.getFullYear()}${pad2(joinAt.getMonth() + 1)}${pad2(joinAt.getDate())}${pad2(joinAt.getHours())}${pad2(joinAt.getMinutes())}${pad2(joinAt.getSeconds())}-${todayCount.toString().padStart(4, "0")}`;

  const existingWbIds = new Set(
    (db.prepare("SELECT CAST(Id AS TEXT) AS Id FROM Waybills").all() as { Id: string }[]).map((r) => r.Id),
  );
  const waybillId = nextWaybillId(existingWbIds);

  const absPhotoDir = join(paths.photoRoot, "PhotoJianKong", "2026", "09", "01");
  mkdirSync(absPhotoDir, { recursive: true });

  const tx = db.prepare("BEGIN IMMEDIATE");
  const commit = db.prepare("COMMIT");
  const rollback = db.prepare("ROLLBACK");

  try {
    tx.run();

    db.prepare(
      `INSERT INTO WeighingRecords (
        TotalWeight, PlateNumber, ProviderId, DeliveryType, MatchedId, WaybillId, MatchedType,
        MaterialsJson, LastEditUserId, LastEditor, CreateUserId, Creator, UpdateTime, AddTime,
        UpdateDate, AddDate, IsDeleted, DeletionTime, DeleterId, ExtraProperties, WeighingMode
      ) VALUES (
        ?, ?, NULL, ?, NULL, NULL, NULL,
        NULL, ?, ?, ?, ?, ?, ?,
        ?, ?, 0, NULL, NULL, '{}', ?
      )`,
    ).run(
      scenario.joinWeightTon,
      scenario.plateNumber,
      scenario.deliveryType,
      creatorId,
      creator,
      creatorId,
      creator,
      joinUnix,
      joinUnix,
      joinText,
      joinText,
      scenario.weighingMode,
    );

    const joinId = Number((db.prepare("SELECT last_insert_rowid() AS id").get() as { id: number }).id);

    const attachmentIds: number[] = [];
    for (const src of images) {
      const fileName = basename(src);
      if (!GUID_FILE_RE.test(fileName)) {
        throw new Error(`Invalid attachment file name: ${fileName}`);
      }
      const destAbs = join(absPhotoDir, fileName);
      const localPath = toLocalPath(photoRelDir, fileName);
      if (resolve(src) !== resolve(destAbs)) {
        copyFileSync(src, destAbs);
      }

      db.prepare(
        `INSERT INTO AttachmentFiles (
          FileName, LocalPath, OssFullPath, AttachType, LastSyncTime,
          LastEditUserId, LastEditor, CreateUserId, Creator, UpdateTime, AddTime,
          UpdateDate, AddDate, IsDeleted, DeletionTime, DeleterId
        ) VALUES (
          ?, ?, NULL, ?, NULL,
          ?, ?, ?, ?, ?, ?,
          ?, ?, 0, NULL, NULL
        )`,
      ).run(
        fileName,
        localPath,
        AttachType.UnmatchedEntryPhoto,
        creatorId,
        creator,
        creatorId,
        creator,
        joinUnix,
        joinUnix,
        joinText,
        joinText,
      );
      const afId = Number((db.prepare("SELECT last_insert_rowid() AS id").get() as { id: number }).id);
      attachmentIds.push(afId);
      db.prepare(
        `INSERT INTO WeighingRecordAttachments (WeighingRecordId, AttachmentFileId) VALUES (?, ?)`,
      ).run(joinId, afId);
    }

    db.prepare(
      `INSERT INTO Waybills (
        Id, ProviderId, OrderNo, OrderType, DeliveryType, PlateNumber, JoinTime, OutTime, Remark,
        OrderPlanOnWeight, OrderPlanOnPcs, OrderPcs, OrderTotalWeight, OrderTruckWeight, OrderGoodsWeight,
        LastSyncTime, IsPendingSync, IsEarlyWarn, PrintCount, AbortReason, OffsetResult, OffsetRate, OffsetCount,
        EarlyWarnType, OrderSource, MaterialId, MaterialUnitId, MaterialUnitRate,
        LastEditUserId, LastEditor, CreateUserId, Creator, UpdateTime, AddTime, UpdateDate, AddDate,
        IsDeleted, DeletionTime, DeleterId, ExtraProperties, WeighingMode
      ) VALUES (
        ?, NULL, ?, ?, ?, ?, ?, ?, NULL,
        NULL, NULL, NULL, ?, ?, ?,
        NULL, ?, 0, 0, NULL, NULL, NULL, NULL,
        NULL, ?, NULL, NULL, NULL,
        ?, ?, ?, ?, ?, ?, ?, ?,
        0, NULL, NULL, '{}', ?
      )`,
    ).run(
      waybillId.toString(),
      orderNo,
      scenario.orderType,
      scenario.deliveryType,
      scenario.plateNumber,
      joinText,
      outAddDate,
      scenario.joinWeightTon,
      scenario.outWeightTon,
      scenario.netWeightTon,
      scenario.isPendingSync ? 1 : 0,
      scenario.orderSource,
      creatorId,
      creator,
      creatorId,
      creator,
      nowUnix,
      nowUnix,
      nowText,
      nowText,
      scenario.weighingMode,
    );

    // Pair both sides
    db.prepare(
      `UPDATE WeighingRecords
       SET MatchedId = ?, WaybillId = ?, MatchedType = ?, UpdateTime = ?, UpdateDate = ?
       WHERE Id = ?`,
    ).run(outId, waybillId.toString(), MatchType.Join, nowUnix, nowText, joinId);

    db.prepare(
      `UPDATE WeighingRecords
       SET MatchedId = ?, WaybillId = ?, MatchedType = ?, UpdateTime = ?, UpdateDate = ?
       WHERE Id = ?`,
    ).run(joinId, waybillId.toString(), MatchType.Out, nowUnix, nowText, outId);

    // Promote attach types + waybill links (join EntryPhoto, out ExitPhoto)
    for (const afId of attachmentIds) {
      db.prepare(`UPDATE AttachmentFiles SET AttachType = ? WHERE Id = ?`).run(AttachType.EntryPhoto, afId);
      db.prepare(`INSERT INTO WaybillAttachments (WaybillId, AttachmentFileId) VALUES (?, ?)`).run(
        waybillId.toString(),
        afId,
      );
    }

    const outAttachRows = db
      .prepare(
        `SELECT af.Id AS Id
         FROM WeighingRecordAttachments wra
         JOIN AttachmentFiles af ON af.Id = wra.AttachmentFileId
         WHERE wra.WeighingRecordId = ?
           AND af.IsDeleted = 0
           AND af.AttachType = ?`,
      )
      .all(outId, AttachType.UnmatchedEntryPhoto) as { Id: number }[];

    for (const row of outAttachRows) {
      db.prepare(`UPDATE AttachmentFiles SET AttachType = ? WHERE Id = ?`).run(AttachType.ExitPhoto, row.Id);
      db.prepare(`INSERT INTO WaybillAttachments (WaybillId, AttachmentFileId) VALUES (?, ?)`).run(
        waybillId.toString(),
        row.Id,
      );
    }

    commit.run();

    // Validate
    const joinCheck = db.prepare("SELECT * FROM WeighingRecords WHERE Id = ?").get(joinId) as Record<string, unknown>;
    const outCheck = db.prepare("SELECT * FROM WeighingRecords WHERE Id = ?").get(outId) as Record<string, unknown>;
    const wbCheck = db.prepare("SELECT * FROM Waybills WHERE Id = ?").get(waybillId.toString()) as Record<
      string,
      unknown
    >;
    const entryPhotoCount = (
      db
        .prepare(
          `SELECT COUNT(*) AS c FROM WeighingRecordAttachments wra
           JOIN AttachmentFiles af ON af.Id = wra.AttachmentFileId
           WHERE wra.WeighingRecordId = ? AND af.AttachType = ?`,
        )
        .get(joinId, AttachType.EntryPhoto) as { c: number }
    ).c;
    const exitPhotoCount = (
      db
        .prepare(
          `SELECT COUNT(*) AS c FROM WeighingRecordAttachments wra
           JOIN AttachmentFiles af ON af.Id = wra.AttachmentFileId
           WHERE wra.WeighingRecordId = ? AND af.AttachType = ?`,
        )
        .get(outId, AttachType.ExitPhoto) as { c: number }
    ).c;
    const waCount = (
      db.prepare(`SELECT COUNT(*) AS c FROM WaybillAttachments WHERE WaybillId = ?`).get(waybillId.toString()) as {
        c: number;
      }
    ).c;

    const integrity = {
      joinId,
      outId,
      waybillId: waybillId.toString(),
      orderNo,
      mutualMatch:
        Number(joinCheck.MatchedId) === outId &&
        Number(outCheck.MatchedId) === joinId &&
        String(joinCheck.WaybillId) === waybillId.toString() &&
        String(outCheck.WaybillId) === waybillId.toString() &&
        Number(joinCheck.MatchedType) === MatchType.Join &&
        Number(outCheck.MatchedType) === MatchType.Out,
      weights:
        almostEqual(dec(String(wbCheck.OrderTotalWeight)), joinWeight) &&
        almostEqual(dec(String(wbCheck.OrderTruckWeight)), outWeight) &&
        almostEqual(dec(String(wbCheck.OrderGoodsWeight)), netWeight),
      entryPhotoCount,
      exitPhotoCount,
      waybillAttachmentCount: waCount,
      expectedEntryPhotos: images.length,
    };

    const l2 =
      integrity.mutualMatch &&
      integrity.weights &&
      integrity.entryPhotoCount === images.length &&
      integrity.exitPhotoCount >= 1 &&
      integrity.waybillAttachmentCount >= images.length + integrity.exitPhotoCount;

    writeJson(join(prepareDir, "result.json"), { integrity, joinCheck, outCheck, waybill: wbCheck });
    writeSummary(paths.runDir, {
      dryRun: false,
      L0: "pass",
      L1: "pass",
      L2: l2 ? "pass" : "fail",
      ...integrity,
    });

    console.log(
      `Wrote join=${joinId} out=${outId} waybill=${waybillId} orderNo=${orderNo} L2=${l2 ? "pass" : "fail"}`,
    );
    process.exit(l2 ? 0 : 1);
  } catch (err) {
    try {
      rollback.run();
    } catch {
      /* ignore */
    }
    throw err;
  } finally {
    db.close();
  }
}

function writeSummary(runDir: string, body: Record<string, unknown>): void {
  const summary = {
    slug: "solidwaste-pair-ingest",
    family: "ingest",
    L3: "pending-user",
    ...body,
  };
  writeJson(join(runDir, "summary.json"), summary);

  const lines = [
    "# Report - solidwaste-pair-ingest",
    "",
    `Status: **${String(body.L2 ?? "pending")}** (L3 pending-user)`,
    "",
    "| Item | Value |",
    "|------|-------|",
    `| dryRun | ${String(body.dryRun)} |`,
    `| L0 | ${String(body.L0)} |`,
    `| L1 | ${String(body.L1)} |`,
    `| L2 | ${String(body.L2)} |`,
    `| joinRecordId | ${String(body.joinRecordId ?? body.joinId ?? "")} |`,
    `| outRecordId | ${String(body.outRecordId ?? "")} |`,
    `| waybillId | ${String(body.waybillId ?? "")} |`,
    `| message | ${String(body.message ?? "")} |`,
    "",
    "Agent does not declare L3 pass.",
  ];
  writeFileSync(join(runDir, "report.md"), lines.join("\n"), "utf8");
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain || process.argv[1]?.endsWith("ingest-pair.ts")) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.stack ?? err.message : err);
    process.exit(2);
  });
}
