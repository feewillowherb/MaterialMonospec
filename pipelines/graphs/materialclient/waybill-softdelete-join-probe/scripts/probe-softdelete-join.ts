/**
 * Experimental: read-only SQLite probe — soft-delete join gaps for Waybill/order queries.
 * MUST NOT write to the database. MUST NOT modify repos/.
 */
import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync, existsSync, statSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";

type Row = Record<string, unknown>;

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
  const buf = readFileSync(path);
  return createHash("sha256").update(buf).digest("hex");
}

function qAll(db: DatabaseSync, sql: string, params: unknown[] = []): Row[] {
  return db.prepare(sql).all(...params) as Row[];
}

function qGet(db: DatabaseSync, sql: string, params: unknown[] = []): Row {
  return db.prepare(sql).get(...params) as Row;
}

function num(row: Row | undefined, key = "c"): number {
  if (!row) return 0;
  const v = row[key];
  return typeof v === "number" ? v : Number(v ?? 0);
}

function tableExists(db: DatabaseSync, name: string): boolean {
  const row = qGet(
    db,
    `SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name=?`,
    [name],
  );
  return num(row) > 0;
}

function columnNames(db: DatabaseSync, table: string): string[] {
  return qAll(db, `PRAGMA table_info("${table}")`).map((c) => String(c.name));
}

function main() {
  const databasePath = mustArg("--database");
  const runDir = mustArg("--runDir");
  const sampleLimit = Number(argValue("--sampleLimit") ?? "20");

  ensureDir(runDir);
  const prepareDir = join(runDir, "prepare");
  const samplesDir = join(runDir, "samples");
  ensureDir(prepareDir);
  ensureDir(samplesDir);

  if (!existsSync(databasePath)) {
    writeJson(join(prepareDir, "bind.json"), {
      ok: false,
      source: "missing",
      databasePath,
    });
    writeJson(join(runDir, "summary.json"), {
      ok: false,
      level: "L0",
      error: "database_missing",
      databasePath,
    });
    writeFileSync(
      join(runDir, "report.md"),
      `# waybill-softdelete-join-probe\n\nDB missing: \`${databasePath}\`\n\n等待用户验收，尚未通过。\n`,
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
  });

  const db = new DatabaseSync(databasePath, { readOnly: true });

  const required = ["Waybills", "Materials", "Providers"] as const;
  const present: Record<string, boolean> = {};
  for (const t of required) present[t] = tableExists(db, t);
  const hasWaybillMaterials = tableExists(db, "WaybillMaterials");
  present.WaybillMaterials = hasWaybillMaterials;

  if (!present.Waybills || !present.Materials || !present.Providers) {
    writeJson(join(runDir, "summary.json"), {
      ok: false,
      level: "L0",
      error: "required_tables_missing",
      present,
    });
    writeFileSync(
      join(runDir, "report.md"),
      `# waybill-softdelete-join-probe\n\nRequired tables missing: ${JSON.stringify(present)}\n\n等待用户验收，尚未通过。\n`,
      "utf8",
    );
    process.exitCode = 2;
    return;
  }

  const materialCols = columnNames(db, "Materials");
  const providerCols = columnNames(db, "Providers");
  const softDeleteColumnsOk =
    materialCols.includes("IsDeleted") && providerCols.includes("IsDeleted");

  const masters = {
    materials_total: num(qGet(db, `SELECT COUNT(*) AS c FROM Materials`)),
    materials_active: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Materials WHERE IsDeleted=0`),
    ),
    materials_soft_deleted: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Materials WHERE IsDeleted=1`),
    ),
    providers_total: num(qGet(db, `SELECT COUNT(*) AS c FROM Providers`)),
    providers_active: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Providers WHERE IsDeleted=0`),
    ),
    providers_soft_deleted: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Providers WHERE IsDeleted=1`),
    ),
    waybills_active: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Waybills WHERE IsDeleted=0`),
    ),
    waybills_soft_deleted: num(
      qGet(db, `SELECT COUNT(*) AS c FROM Waybills WHERE IsDeleted=1`),
    ),
  };

  const waybillMaterialHardMissing = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       WHERE w.IsDeleted=0
         AND w.MaterialId IS NOT NULL AND w.MaterialId != 0
         AND NOT EXISTS (SELECT 1 FROM Materials m WHERE m.Id = w.MaterialId)`,
    ),
  );
  const waybillMaterialSoftDeleted = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       JOIN Materials m ON m.Id = w.MaterialId
       WHERE w.IsDeleted=0 AND m.IsDeleted=1`,
    ),
  );
  const waybillProviderHardMissing = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       WHERE w.IsDeleted=0
         AND w.ProviderId IS NOT NULL AND w.ProviderId != 0
         AND NOT EXISTS (SELECT 1 FROM Providers p WHERE p.Id = w.ProviderId)`,
    ),
  );
  const waybillProviderSoftDeleted = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       JOIN Providers p ON p.Id = w.ProviderId
       WHERE w.IsDeleted=0 AND p.IsDeleted=1`,
    ),
  );

  const waybillsWithMaterialId = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       WHERE w.IsDeleted=0 AND w.MaterialId IS NOT NULL AND w.MaterialId != 0`,
    ),
  );
  const joinActiveMaterialOnly = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       INNER JOIN Materials m ON m.Id = w.MaterialId AND m.IsDeleted=0
       WHERE w.IsDeleted=0 AND w.MaterialId IS NOT NULL AND w.MaterialId != 0`,
    ),
  );
  const joinIncludeSoftMaterial = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       INNER JOIN Materials m ON m.Id = w.MaterialId
       WHERE w.IsDeleted=0 AND w.MaterialId IS NOT NULL AND w.MaterialId != 0`,
    ),
  );
  const activeOnlyMaterialGap = joinIncludeSoftMaterial - joinActiveMaterialOnly;

  const waybillsWithProviderId = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       WHERE w.IsDeleted=0 AND w.ProviderId IS NOT NULL AND w.ProviderId != 0`,
    ),
  );
  const joinActiveProviderOnly = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       INNER JOIN Providers p ON p.Id = w.ProviderId AND p.IsDeleted=0
       WHERE w.IsDeleted=0 AND w.ProviderId IS NOT NULL AND w.ProviderId != 0`,
    ),
  );
  const joinIncludeSoftProvider = num(
    qGet(
      db,
      `SELECT COUNT(*) AS c FROM Waybills w
       INNER JOIN Providers p ON p.Id = w.ProviderId
       WHERE w.IsDeleted=0 AND w.ProviderId IS NOT NULL AND w.ProviderId != 0`,
    ),
  );
  const activeOnlyProviderGap = joinIncludeSoftProvider - joinActiveProviderOnly;

  let waybillMaterialsSoftDeleted = 0;
  let waybillMaterialsHardMissing = 0;
  if (hasWaybillMaterials) {
    waybillMaterialsHardMissing = num(
      qGet(
        db,
        `SELECT COUNT(*) AS c FROM WaybillMaterials wm
         WHERE wm.IsDeleted=0
           AND wm.MaterialId IS NOT NULL AND wm.MaterialId != 0
           AND NOT EXISTS (SELECT 1 FROM Materials m WHERE m.Id = wm.MaterialId)`,
      ),
    );
    waybillMaterialsSoftDeleted = num(
      qGet(
        db,
        `SELECT COUNT(*) AS c FROM WaybillMaterials wm
         JOIN Materials m ON m.Id = wm.MaterialId
         WHERE wm.IsDeleted=0 AND m.IsDeleted=1`,
      ),
    );
  }

  const softMaterialsByImpact = qAll(
    db,
    `SELECT m.Id AS materialId, m.Name AS materialName, m.DeletionTime AS deletionTime, COUNT(*) AS waybillCount
     FROM Waybills w
     JOIN Materials m ON m.Id = w.MaterialId
     WHERE w.IsDeleted=0 AND m.IsDeleted=1
     GROUP BY m.Id, m.Name, m.DeletionTime
     ORDER BY waybillCount DESC`,
  );
  writeJson(join(samplesDir, "soft-deleted-materials-by-waybill-count.json"), softMaterialsByImpact);

  const softMaterialWaybillSamples = qAll(
    db,
    `SELECT w.Id AS waybillId, w.OrderNo AS orderNo, w.PlateNumber AS plateNumber,
            w.MaterialId AS materialId, m.Name AS materialName, m.IsDeleted AS materialIsDeleted,
            m.DeletionTime AS materialDeletionTime,
            w.ProviderId AS providerId
     FROM Waybills w
     JOIN Materials m ON m.Id = w.MaterialId
     WHERE w.IsDeleted=0 AND m.IsDeleted=1
     ORDER BY w.Id
     LIMIT ?`,
    [sampleLimit],
  );
  writeJson(join(samplesDir, "waybills-soft-deleted-material.json"), softMaterialWaybillSamples);

  const softProviderWaybillSamples = qAll(
    db,
    `SELECT w.Id AS waybillId, w.OrderNo AS orderNo, w.PlateNumber AS plateNumber,
            w.ProviderId AS providerId, p.ProviderName AS providerName, p.IsDeleted AS providerIsDeleted,
            p.DeletionTime AS providerDeletionTime
     FROM Waybills w
     JOIN Providers p ON p.Id = w.ProviderId
     WHERE w.IsDeleted=0 AND p.IsDeleted=1
     ORDER BY w.Id
     LIMIT ?`,
    [sampleLimit],
  );
  writeJson(join(samplesDir, "waybills-soft-deleted-provider.json"), softProviderWaybillSamples);

  const deletedMaterials = qAll(
    db,
    `SELECT Id, Name, IsDeleted, DeletionTime, DeleterId FROM Materials WHERE IsDeleted=1 ORDER BY Id`,
  );
  writeJson(join(samplesDir, "materials-isdeleted-1.json"), deletedMaterials);

  const deletedProviders = qAll(
    db,
    `SELECT Id, ProviderName, IsDeleted, DeletionTime, DeleterId FROM Providers WHERE IsDeleted=1 ORDER BY Id`,
  );
  writeJson(join(samplesDir, "providers-isdeleted-1.json"), deletedProviders);

  const classification =
    waybillMaterialHardMissing === 0 && waybillMaterialSoftDeleted > 0
      ? "soft-delete-filtered-join"
      : waybillMaterialHardMissing > 0 && waybillMaterialSoftDeleted === 0
        ? "hard-missing-fk"
        : waybillMaterialHardMissing > 0 && waybillMaterialSoftDeleted > 0
          ? "mixed-hard-and-soft"
          : waybillMaterialSoftDeleted === 0 && waybillMaterialHardMissing === 0
            ? "no-material-gap"
            : "unknown";

  const summary = {
    ok: true,
    readOnly: true,
    databasePath,
    sha256: hash,
    softDeleteColumnsOk,
    present,
    masters,
    gaps: {
      waybill_material_hard_missing: waybillMaterialHardMissing,
      waybill_material_soft_deleted: waybillMaterialSoftDeleted,
      waybill_provider_hard_missing: waybillProviderHardMissing,
      waybill_provider_soft_deleted: waybillProviderSoftDeleted,
      waybill_materials_row_hard_missing: waybillMaterialsHardMissing,
      waybill_materials_row_soft_deleted: waybillMaterialsSoftDeleted,
      active_only_material_gap: activeOnlyMaterialGap,
      active_only_provider_gap: activeOnlyProviderGap,
    },
    joinSimulation: {
      waybills_with_material_id: waybillsWithMaterialId,
      join_include_soft_material: joinIncludeSoftMaterial,
      join_active_material_only: joinActiveMaterialOnly,
      waybills_with_provider_id: waybillsWithProviderId,
      join_include_soft_provider: joinIncludeSoftProvider,
      join_active_provider_only: joinActiveProviderOnly,
    },
    classification,
    codeHypothesis:
      "Order/export dict builders use IRepository.GetQueryableAsync() on Material/Provider (IDeletionAuditedObject). Soft-deleted masters are filtered out → MaterialName/ProviderName empty while Waybill.MaterialId/ProviderId remain.",
    codeRefs: [
      "repos/MaterialClient/src/MaterialClient.Common/Services/SolidWasteService.cs",
      "repos/MaterialClient/src/MaterialClient.Common/Services/StandardService.cs",
      "repos/MaterialClient/src/MaterialClient.Common/Services/StandardModeService.cs",
      "repos/MaterialClient/src/MaterialClient.Common/Models/WeighingListItemDto.cs",
    ],
    levels: {
      L0: true,
      L1: softDeleteColumnsOk,
      L2: true,
      L3: "user",
    },
  };
  writeJson(join(runDir, "summary.json"), summary);

  const report = `# waybill-softdelete-join-probe

只读探针。**等待用户验收，尚未通过。**

## 库

- path: \`${databasePath}\`
- sha256: \`${hash}\`
- size: ${st.size} bytes

## 主数据

| 表 | total | active (IsDeleted=0) | soft-deleted (IsDeleted=1) |
|----|------:|---------------------:|---------------------------:|
| Materials | ${masters.materials_total} | ${masters.materials_active} | ${masters.materials_soft_deleted} |
| Providers | ${masters.providers_total} | ${masters.providers_active} | ${masters.providers_soft_deleted} |
| Waybills | ${masters.waybills_active + masters.waybills_soft_deleted} | ${masters.waybills_active} | ${masters.waybills_soft_deleted} |

软删列存在（L1）: **${softDeleteColumnsOk}**

## 订单缺口分类

| 检查 | 计数 |
|------|-----:|
| Waybill→Material **硬缺失**（行不存在） | ${waybillMaterialHardMissing} |
| Waybill→Material **软删引用**（行在且 IsDeleted=1） | ${waybillMaterialSoftDeleted} |
| Waybill→Provider 硬缺失 | ${waybillProviderHardMissing} |
| Waybill→Provider 软删引用 | ${waybillProviderSoftDeleted} |
| WaybillMaterials→Material 硬缺失 | ${waybillMaterialsHardMissing} |
| WaybillMaterials→Material 软删引用 | ${waybillMaterialsSoftDeleted} |

**classification:** \`${classification}\`

## active-only join 模拟（对齐 Repository 默认过滤）

| 模拟 | 计数 |
|------|-----:|
| 有 MaterialId 的活跃 Waybill | ${waybillsWithMaterialId} |
| INNER JOIN Materials（含软删） | ${joinIncludeSoftMaterial} |
| INNER JOIN Materials AND IsDeleted=0 | ${joinActiveMaterialOnly} |
| **material 信息缺口** | **${activeOnlyMaterialGap}** |
| 有 ProviderId 的活跃 Waybill | ${waybillsWithProviderId} |
| INNER JOIN Providers（含软删） | ${joinIncludeSoftProvider} |
| INNER JOIN Providers AND IsDeleted=0 | ${joinActiveProviderOnly} |
| **provider 信息缺口** | **${activeOnlyProviderGap}** |

## 解读

- 若硬缺失 ≈ 0 且软删引用 > 0：材料/供应商**已被软删除**，行仍在库中；订单查询若走 active-only 字典填充，会出现空材料名/供应商名。
- 期望修复方向（**本 Graph 不实现**）：订单/列表/导出在解析展示名时 \`IgnoreQueryFilters\` 或按 Id 查含软删主数据，使所有 order 查询仍能显示历史材料/供应商。
- 抽样见 \`samples/\`。

## 代码对照（只读）

- \`SolidWasteService\` / \`StandardService\` / \`StandardModeService\`：\`BuildMaterialDictAsync\` / \`BuildProviderDictAsync\`
- \`WeighingListItemDto.FromWaybill\`：依赖传入的 \`materialsDict\`
- 实体 \`Material\` / \`Provider\`：\`IDeletionAuditedObject\`

请验收：\`pass\` / \`fail\` + 对象与原因。
`;

  writeFileSync(join(runDir, "report.md"), report, "utf8");
  console.log(JSON.stringify({ ok: true, runDir, classification, gaps: summary.gaps }, null, 2));
}

main();
