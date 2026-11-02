/**
 * Experimental transform: SolidWaste October export to xlsx.
 * Layout parity with ExcelExportService; master names include soft-deleted rows.
 * Read-only against SQLite. MUST NOT modify repos/ or the site DB.
 */
import { createHash } from "node:crypto";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import ExcelJS from "exceljs";

type Row = Record<string, unknown>;

const HEADERS = [
  "流水号",
  "车  号",
  "称重类型",
  "发货单位",
  "收货单位",
  "货  名",
  "毛  重",
  "皮  重",
  "净  重",
  "备 注",
  "毛重时间",
  "皮重时间",
  "所属街道",
  "类型",
  "联单编号",
  "上传结果",
  "上传状态",
  "上传时间",
] as const;

const DEFAULT_SHIPPER = "东部资源化处置点";
const EXTRA_KEYS = {
  type: "SolidWasteInfo.SolidWasteType",
  street: "SolidWasteInfo.Street",
  orderNumber: "SolidWasteInfo.SolidWasteOrderNumber",
  shipper: "SolidWasteInfo.Shipper",
} as const;

type ExportRow = {
  serialNumber: string;
  vehicleNumber: string;
  weighingType: string;
  shippingUnit: string;
  receivingUnit: string;
  goodsName: string;
  grossWeight: number;
  tareWeight: number;
  netWeight: number;
  remark: string;
  grossWeightTime: string;
  tareWeightTime: string;
  street: string;
  solidWasteType: string;
  manifestNumber: string;
  uploadResult: string;
  uploadStatus: string;
  uploadTime: string;
  _meta: {
    waybillId: string;
    materialId: number | null;
    providerId: number | null;
    materialSoftDeleted: boolean;
    providerSoftDeleted: boolean;
  };
};

function argValue(flag: string): string | undefined {
  const i = process.argv.indexOf(flag);
  if (i < 0 || i + 1 >= process.argv.length) return undefined;
  return process.argv[i + 1];
}

function mustArg(flag: string): string {
  const v = argValue(flag);
  if (!v) throw new Error(`Missing required arg ${flag}`);
  return v;
}

function ensureDir(p: string) {
  mkdirSync(p, { recursive: true });
}

function writeJson(path: string, data: unknown) {
  ensureDir(dirname(path));
  writeFileSync(path, JSON.stringify(data, null, 2) + "\n", "utf8");
}

function sha256File(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function asNum(v: unknown): number {
  if (v == null || v === "") return 0;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : 0;
}

function asStr(v: unknown): string {
  if (v == null) return "";
  return String(v);
}

function formatDateTime(v: unknown): string {
  const s = asStr(v).trim();
  if (!s) return "";
  // Keep app-like "yyyy-MM-dd HH:mm:ss" (trim fractional seconds if present)
  const m = s.match(/^(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})/);
  if (m) return m[1]!.replace("T", " ");
  return s;
}

function parseExtra(raw: unknown): Record<string, unknown> {
  const s = asStr(raw).trim();
  if (!s) return {};
  try {
    const obj = JSON.parse(s) as unknown;
    return obj && typeof obj === "object" ? (obj as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function csvEscape(v: string | number): string {
  const s = String(v);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

async function main() {
  const databasePath = mustArg("--database");
  const runDir = mustArg("--runDir");
  const outLatestDir = argValue("--outLatest") ?? "";
  const startDate = argValue("--startDate") ?? "2026-10-01";
  const endExclusive = argValue("--endExclusive") ?? "2026-11-01";
  const weighingMode = Number(argValue("--weighingMode") ?? "1");
  const orderType = Number(argValue("--orderType") ?? "1");
  const defaultShipper = argValue("--defaultShipper") ?? DEFAULT_SHIPPER;
  const outputFileName =
    argValue("--outputFileName") ??
    "solidwaste-export-2026-10-include-softdelete.xlsx";
  const sheetName = argValue("--sheetName") ?? "Sheet1";

  ensureDir(runDir);
  const prepareDir = join(runDir, "prepare");
  const exportDir = join(runDir, "export");
  ensureDir(prepareDir);
  ensureDir(exportDir);

  if (!existsSync(databasePath)) {
    writeJson(join(prepareDir, "bind.json"), {
      ok: false,
      source: "missing",
      databasePath,
    });
    writeJson(join(runDir, "summary.json"), {
      ok: false,
      error: "database_missing",
      databasePath,
    });
    writeFileSync(
      join(runDir, "report.md"),
      `# solidwaste-oct-export-include-softdelete\n\nDB missing: \`${databasePath}\`\n\n等待用户验收，尚未通过。\n`,
      "utf8",
    );
    process.exitCode = 2;
    return;
  }

  const st = statSync(databasePath);
  const hash = sha256File(databasePath);
  writeJson(join(prepareDir, "bind.json"), {
    ok: true,
    databasePath,
    sizeBytes: st.size,
    mtimeMs: st.mtimeMs,
    sha256: hash,
    readOnly: true,
    startDate,
    endExclusive,
  });

  const db = new DatabaseSync(databasePath, { readOnly: true });

  const waybills = db
    .prepare(
      `SELECT Id, OrderNo, PlateNumber, DeliveryType, ProviderId, MaterialId,
              OrderTotalWeight, OrderTruckWeight, OrderGoodsWeight, Remark,
              JoinTime, OutTime, IsPendingSync, LastSyncTime, ExtraProperties, AddDate
       FROM Waybills
       WHERE IsDeleted = 0
         AND WeighingMode = ?
         AND OrderType = ?
         AND AddDate >= ?
         AND AddDate < ?
       ORDER BY AddDate`,
    )
    .all(weighingMode, orderType, startDate, endExclusive) as Row[];

  const materialIds = [
    ...new Set(
      waybills
        .map((w) => Number(w.MaterialId))
        .filter((id) => Number.isFinite(id) && id !== 0),
    ),
  ];
  const providerIds = [
    ...new Set(
      waybills
        .map((w) => Number(w.ProviderId))
        .filter((id) => Number.isFinite(id) && id !== 0),
    ),
  ];

  const materialById = new Map<
    number,
    { name: string; isDeleted: boolean }
  >();
  if (materialIds.length > 0) {
    const placeholders = materialIds.map(() => "?").join(",");
    const mats = db
      .prepare(
        `SELECT Id, Name, IsDeleted FROM Materials WHERE Id IN (${placeholders})`,
      )
      .all(...materialIds) as Row[];
    for (const m of mats) {
      materialById.set(Number(m.Id), {
        name: asStr(m.Name),
        isDeleted: Number(m.IsDeleted) === 1,
      });
    }
  }

  const providerById = new Map<
    number,
    { name: string; isDeleted: boolean }
  >();
  if (providerIds.length > 0) {
    const placeholders = providerIds.map(() => "?").join(",");
    const provs = db
      .prepare(
        `SELECT Id, ProviderName, IsDeleted FROM Providers WHERE Id IN (${placeholders})`,
      )
      .all(...providerIds) as Row[];
    for (const p of provs) {
      providerById.set(Number(p.Id), {
        name: asStr(p.ProviderName),
        isDeleted: Number(p.IsDeleted) === 1,
      });
    }
  }

  const rows: ExportRow[] = [];
  let softMaterialResolved = 0;
  let softProviderResolved = 0;
  let missingMaterial = 0;
  let missingProvider = 0;

  for (const w of waybills) {
    const mid =
      w.MaterialId == null || w.MaterialId === ""
        ? null
        : Number(w.MaterialId);
    const pid =
      w.ProviderId == null || w.ProviderId === ""
        ? null
        : Number(w.ProviderId);

    let goodsName = "";
    let materialSoftDeleted = false;
    if (mid != null && Number.isFinite(mid) && mid !== 0) {
      const m = materialById.get(mid);
      if (m) {
        goodsName = m.name;
        materialSoftDeleted = m.isDeleted;
        if (m.isDeleted) softMaterialResolved++;
      } else {
        missingMaterial++;
      }
    }

    let providerName = "";
    let providerSoftDeleted = false;
    if (pid != null && Number.isFinite(pid) && pid !== 0) {
      const p = providerById.get(pid);
      if (p) {
        providerName = p.name;
        providerSoftDeleted = p.isDeleted;
        if (p.isDeleted) softProviderResolved++;
      } else {
        missingProvider++;
      }
    }

    const extra = parseExtra(w.ExtraProperties);
    const shipper = asStr(extra[EXTRA_KEYS.shipper]) || defaultShipper;
    const deliveryType = Number(w.DeliveryType);
    // DeliveryType.Sending = 1 → swap; Receiving = 0 → provider ships, shipper receives
    const shippingUnit = deliveryType === 1 ? shipper : providerName;
    const receivingUnit = deliveryType === 1 ? providerName : shipper;
    const weighingType =
      deliveryType === 1 ? "发料" : deliveryType === 0 ? "收料" : "";

    const pending = Number(w.IsPendingSync) === 1;

    rows.push({
      serialNumber: asStr(w.OrderNo),
      vehicleNumber: asStr(w.PlateNumber),
      weighingType,
      shippingUnit,
      receivingUnit,
      goodsName,
      grossWeight: asNum(w.OrderTotalWeight),
      tareWeight: asNum(w.OrderTruckWeight),
      netWeight: asNum(w.OrderGoodsWeight),
      remark: asStr(w.Remark),
      grossWeightTime: formatDateTime(w.JoinTime),
      tareWeightTime: formatDateTime(w.OutTime),
      street: asStr(extra[EXTRA_KEYS.street]),
      solidWasteType: asStr(extra[EXTRA_KEYS.type]),
      manifestNumber: asStr(extra[EXTRA_KEYS.orderNumber]),
      uploadResult: pending ? "0" : "1",
      uploadStatus: pending ? "未上传" : "上传成功",
      uploadTime: formatDateTime(w.LastSyncTime),
      _meta: {
        waybillId: asStr(w.Id),
        materialId: mid != null && Number.isFinite(mid) ? mid : null,
        providerId: pid != null && Number.isFinite(pid) ? pid : null,
        materialSoftDeleted,
        providerSoftDeleted,
      },
    });
  }

  const xlsxPath = join(exportDir, outputFileName);
  const csvPath = join(
    exportDir,
    outputFileName.replace(/\.xlsx$/i, "") + ".csv",
  );

  const workbook = new ExcelJS.Workbook();
  const ws = workbook.addWorksheet(sheetName);
  ws.addRow([...HEADERS]);
  for (const r of rows) {
    ws.addRow([
      r.serialNumber,
      r.vehicleNumber,
      r.weighingType,
      r.shippingUnit,
      r.receivingUnit,
      r.goodsName,
      r.grossWeight,
      r.tareWeight,
      r.netWeight,
      r.remark,
      r.grossWeightTime,
      r.tareWeightTime,
      r.street,
      r.solidWasteType,
      r.manifestNumber,
      r.uploadResult,
      r.uploadStatus,
      r.uploadTime,
    ]);
  }
  // Summary row (ExcelExportService.GetSummaryRow)
  ws.addRow([
    rows.length,
    "",
    "",
    "",
    "",
    "",
    rows.reduce((s, r) => s + r.grossWeight, 0),
    rows.reduce((s, r) => s + r.tareWeight, 0),
    rows.reduce((s, r) => s + r.netWeight, 0),
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
  ]);
  await workbook.xlsx.writeFile(xlsxPath);

  const csvLines = [
    HEADERS.map(csvEscape).join(","),
    ...rows.map((r) =>
      [
        r.serialNumber,
        r.vehicleNumber,
        r.weighingType,
        r.shippingUnit,
        r.receivingUnit,
        r.goodsName,
        r.grossWeight,
        r.tareWeight,
        r.netWeight,
        r.remark,
        r.grossWeightTime,
        r.tareWeightTime,
        r.street,
        r.solidWasteType,
        r.manifestNumber,
        r.uploadResult,
        r.uploadStatus,
        r.uploadTime,
      ]
        .map(csvEscape)
        .join(","),
    ),
  ];
  writeFileSync(csvPath, "\uFEFF" + csvLines.join("\n") + "\n", "utf8");

  const softSamples = rows
    .filter((r) => r._meta.materialSoftDeleted || r._meta.providerSoftDeleted)
    .slice(0, 20)
    .map((r) => ({
      serialNumber: r.serialNumber,
      goodsName: r.goodsName,
      shippingUnit: r.shippingUnit,
      receivingUnit: r.receivingUnit,
      materialId: r._meta.materialId,
      providerId: r._meta.providerId,
      materialSoftDeleted: r._meta.materialSoftDeleted,
      providerSoftDeleted: r._meta.providerSoftDeleted,
    }));
  writeJson(join(prepareDir, "soft-master-samples.json"), softSamples);

  if (outLatestDir) {
    ensureDir(outLatestDir);
    copyFileSync(xlsxPath, join(outLatestDir, outputFileName));
    copyFileSync(csvPath, join(outLatestDir, outputFileName.replace(/\.xlsx$/i, "") + ".csv"));
  }

  const summary = {
    ok: true,
    databasePath,
    sha256: hash,
    startDate,
    endExclusive,
    includeSoftDeletedMasters: true,
    rowCount: rows.length,
    softMaterialResolved,
    softProviderResolved,
    missingMaterial,
    missingProvider,
    xlsxPath,
    csvPath,
    headers: HEADERS,
    levels: {
      L0: true,
      L1: rows.length > 0,
      L2: missingMaterial === 0 && softMaterialResolved >= 0,
      L3: "user",
    },
  };
  writeJson(join(runDir, "summary.json"), summary);

  const report = `# solidwaste-oct-export-include-softdelete

只读导出。**等待用户验收，尚未通过。**

## 范围

- DB: \`${databasePath}\`
- AddDate: \`[${startDate}, ${endExclusive})\`
- WeighingMode=${weighingMode} SolidWaste；OrderType=${orderType} Completed
- 主数据：**含软删**（Materials / Providers 按 Id，不排除 IsDeleted=1）

## 结果

| 指标 | 值 |
|------|---:|
| 导出行数 | ${rows.length} |
| 软删材料已解析名称 | ${softMaterialResolved} |
| 软删供应商已解析名称 | ${softProviderResolved} |
| MaterialId 硬缺失 | ${missingMaterial} |
| ProviderId 硬缺失 | ${missingProvider} |

## 产出

- xlsx: \`${xlsxPath}\`
- csv: \`${csvPath}\`

列头对齐 \`ExcelExportService.SolidWasteHeaders\`；末行汇总对齐 \`GetSummaryRow\`。

请验收：\`pass\` / \`fail\` + 对象与原因。
`;
  writeFileSync(join(runDir, "report.md"), report, "utf8");
  console.log(
    JSON.stringify(
      {
        ok: true,
        rowCount: rows.length,
        softMaterialResolved,
        softProviderResolved,
        xlsxPath,
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
