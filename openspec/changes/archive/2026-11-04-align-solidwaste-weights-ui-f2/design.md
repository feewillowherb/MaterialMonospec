## Context

固废 UI 对毛/皮/净用 `F2` 显示吨；库内可保留更多小数。打印已在 `CreateWeighingTicketDtoAsync` 使用 `MaterialMath.ConvertDisplayedTonToKg`（`90dfbb71`）。Excel / 数据管理仍经 `SolidWasteService.SolidWasteMapToExportRow` 直出 `OrderTotalWeight` / `OrderTruckWeight` / `OrderGoodsWeight`，导致表与屏不一致。

调研：`docs/2026-11-04-weight-display-three-decimals/02-固废导出打印对齐UI两位.md`。三位显示已放弃。

## Goals / Non-Goals

**Goals:**

- 固废 Excel 与同源数据管理列表的毛/皮/净吨值与 UI `F2` 一致。
- 规格固化打印千克 MUST 走 Displayed→kg；复核实现，避免二次舍入。
- 舍入口径单一：`Round(ton, 2, MidpointRounding.AwayFromZero)`。

**Non-Goals:**

- 回写 Waybill / 称重记录。
- 改三位显示、偏差/计划重量字段、入库地磅舍入。
- 改 Urban 上云 `ConvertTonToKg`（非 Displayed）。
- 强制圆后毛−皮=净。

## Decisions

### D1: 在导出映射处一次性舍入

在 `SolidWasteMapToExportRow`（或 `SolidWasteExportRow` 的 type-owned `From*`）对毛/皮/净写入两位吨。Excel 与数据管理共用该行，只改一处。

**备选**：仅在 `ExcelExportService.RowToValues` 舍入 → 列表仍露原值，否决。

### D2: 抽出 `MaterialMath` 的 Displayed 吨 API

新增或公开「仅圆到两位吨」的静态方法（如 `RoundToDisplayedTon`），供导出使用；`ConvertDisplayedTonToKg` 委托该方法再 ×1000，避免两套 Round。

**备选**：导出内联 `Math.Round` → 易与打印漂移，否决。

### D3: 汇总行对已圆行求和

`GetSummaryRow` 对行上已是两位的吨求和。接受与「先求原值和再圆」的差异；与「所见行之和」一致。

### D4: 打印只复核不叠圆

`CreateWeighingTicketDtoAsync` 已用 `ConvertDisplayedTonToKg`；实现阶段确认无二次 Round。DTO 千克仍为整数。

### D5: 各字段独立对齐 UI

不按「圆后毛 − 圆后皮」重算净重；净重单独 `Round(OrderGoodsWeight, 2)`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 圆后毛−皮≠净，用户质疑 | 产品已接受；验收说明按字段对齐 UI |
| 汇总与「原值求和再圆」差 0.01 量级 | 文档化；测汇总=各导出行之和 |
| 误改上云换算 | tasks 明确不碰 Urban upload |
| `SolidWasteMapToExportRow` 内既有 tuple 解构 | 本 change 不顺手清扫；触及投影时再迁 record |

## Migration Plan

- 仅客户端行为变更；无 DB migration。
- 回滚：还原映射与（若有）`MaterialMath` 新增 API；打印可保留 Displayed（已是期望行为）。

## Open Questions

（无；口径已由 Human 锁定为两位 + 导出/打印对齐 UI。）
