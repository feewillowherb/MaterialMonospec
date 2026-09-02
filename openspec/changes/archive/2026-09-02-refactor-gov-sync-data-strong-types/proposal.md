## Why

遗留只读表 `GovSyncData` 的 `SnapTime` / `GoodsWeight` 仍为 `string?`，与主路径 `UrbanWeighingRecord`（`WeighingTime` / `TotalWeight`）语义不一致，查询与展示需反复 parse。P0–P2 已完成 enum / ProId / 停双写后，P3 将这两列收紧为强类型，降低历史只读数据的理解成本。

## What Changes

- `GovSyncData.SnapTime`：`string?` → **`DateTime?`**（保留列，不删列）。
- `GovSyncData.GoodsWeight`：`string?` → **`decimal?`**。
- EF migration：历史字符串尽量 parse；无法解析 → `NULL`；再 AlterColumn。
- `GovSyncDataDto` / 只读查询 API：类型同步；JSON **BREAKING**（时间对象 / 数字，不再是纯字符串）。
- Fluent：去掉 `SnapTime` / `GoodsWeight` 的 `HasMaxLength` 字符串配置。
- Git：**Mode B** — `dev-urban-entity-semantic`（**仅 UrbanManagement**）。

**本 change 不包含**：`GovSyncData.SiteType` enum 化；AccessCode 改名（INT-005）；政府 outbound wire payload（`GovSyncWeightPayload` 等仍为 string，D5）；恢复对 `GovSyncData` 的写入；删列。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `entity-migration`: `GovSyncData.SnapTime` / `GoodsWeight` 强类型与 migration。
- `urban-management-crud`: `GovSyncDataDto` 与只读查询映射使用新类型。

## Impact

- **UrbanManagement**：`GovSyncData`、DbContext Fluent、migration、`GovSyncDataDto` / AppService 映射、相关测试；Blazor/样例若绑定这两字段则改类型。
- **MaterialClient / FdSoft.BasePlatform**：无。
- **BREAKING**：`GovSyncData` 查询 API 的 `snapTime` / `goodsWeight` JSON 形状变化。
