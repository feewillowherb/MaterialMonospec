## Why

固废有人值守界面用 `F2`（吨、两位、四舍五入）展示毛重/皮重/净重，但 Excel 导出与数据管理列表仍直出库内更长小数（如 6.045 / 6.995），与屏幕及已对齐的小票千克不一致，现场对账困难。三位小数显示方案已放弃；现需把固废导出（含同源列表）与打印统一到与 UI 相同的两位口径。

## What Changes

- 固废导出行（`SolidWasteExportRow`）的毛重、皮重、净重在映射时按 UI `F2` 口径舍入为两位吨后再写出；数据管理网格同源受益。
- Excel 汇总行对**已舍入行**的毛/皮/净求和。
- 固废小票：`CreateWeighingTicketDtoAsync` 继续（并规范为 MUST）使用 `MaterialMath.ConvertDisplayedTonToKg`，使打印千克与 UI 两位吨一致；不回写库。
- **不**改运单入库精度；**不**改超正差/超负差；**不**把 Urban 上云改为 Displayed 路径（除非另开 change）。
- 接受两位圆后「毛 − 皮 ≠ 净」；按字段各自对齐 UI，不重算净重。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `solidwaste-excel-export`: 毛/皮/净映射从库内原值改为与 UI F2 同口径的两位吨；补充打印千克 MUST 走 Displayed 换算的场景；汇总行基于已圆行求和。

## Impact

- **仓库**：MaterialClient（`SolidWasteService` / `ExcelExportService` / `WeighingMatchingService` / `MaterialMath`；打印路径复核）。
- **调研依据**：`docs/2026-11-04-weight-display-three-decimals/02-固废导出打印对齐UI两位.md`。
- **既有行为**：打印侧 `90dfbb71` 已部分落地；本 change 以规格固化并补齐导出/列表。
