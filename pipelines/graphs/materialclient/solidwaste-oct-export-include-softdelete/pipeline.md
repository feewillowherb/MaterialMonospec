# solidwaste-oct-export-include-softdelete（materialclient）

## 目的 / Goal

从现场固废 SQLite **只读**导出 **2026-10** 已完成固废运单为 `.xlsx`：列头、列序、收发料单位逻辑、汇总行与应用 `ExcelExportService` / `SolidWasteMapToExportRow` **一致**；解析材料名 / 供应商名时 **包含软删除主数据**（`IsDeleted=1` 仍取 Name）。

Goal 槽：`solidwaste-oct-export-include-soft-masters`

Status: **active**

路径：`pipelines/graphs/materialclient/solidwaste-oct-export-include-softdelete/`

## 非目标

- 不修改 `repos/` 业务代码（不修应用内 soft-delete 过滤）
- 不写现场库；只写本 Graph `runs/` / `out/`
- 不提交 secrets / runs / out 产物
- 不替代 OpenSpec；Agent 不宣布 L3 通过

## 与应用一致 / 刻意差异

| 项 | 行为 |
|----|------|
| 筛选 | `WeighingMode=SolidWaste(1)` + `OrderType=Completed(1)` + `AddDate ∈ [start, end+1日)` |
| 18 列表头 | 与 `ExcelExportService.SolidWasteHeaders` 相同（含空格） |
| 收发单位 | `GetSolidWasteShippingAndReceivingUnits`：收料=供应商/shipper；发料对调 |
| ExtraProperties | `SolidWasteInfo.*` JSON 键 |
| 汇总行 | 第 1 列行数；第 7/8/9 列毛/皮/净合计 |
| **主数据名称** | **含软删**（相对当前应用空名 bug 的刻意修复导出） |

## 配置指针

- `./config.yaml`（`scenario.yearMonth` / 日期）
- `./secrets.local.yaml` → `databaseAbs`
- Node：`./scripts/export-solidwaste-october.ts`（`node:sqlite` + `exceljs`）
- 现场库：`D:\新建文件夹\固废\1112\MaterialClient.db`

## 前置

1. Node.js 22.5+；在 `pipelines/` 执行过 `pnpm install`（含 `exceljs`、`tsx`）
2. `secrets.local.yaml` 指向可读 DB

## Sockets

| | |
|--|--|
| Start | `sqlite-idle` |
| End | `xlsx-exported` |
| Cook | `new-object` |

## Context

- 指针：SQLite 绝对路径（secrets）
- 指纹：`Waybills.WeighingMode=1`、`OrderType=1`、`AddDate` 落在 2026-10
- 歧义：DB 不可读或缺表 → 停

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-db]
  QN[query-october]
  ResN[resolve-masters]
  MapN[map-rows]
  WXN[write-xlsx]
  GateN[Gate]
  BindN -->|"sqlite-idle"| QN --> ResN --> MapN -->|"xlsx-exported"| WXN --> GateN
```

失败策略：`retries: 0`；`stopOnError: true`。

## 证据包

相对 `runs/<yyyy-MM-ddTHHmmss>/`：`prepare/`、`export/*.xlsx`、`export/*.csv`、`summary.json`、`report.md`。  
另写 `out/latest/` 便捷副本（gitignore）。

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/solidwaste-oct-export-include-softdelete/scripts/Invoke-SolidwasteOctExport.ps1
```

命令：`/run-pipeline materialclient/solidwaste-oct-export-include-softdelete`

## 人闸 / Gate

- 缺 DB 路径
- L3：用户打开 xlsx 对照列头与抽样（尤其软删材料行货名是否有值）

## Handoff

Output：`xlsx-exported`。不接业务仓改动。
