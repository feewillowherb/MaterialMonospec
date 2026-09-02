## Context

- 调研 P3 / T1：`SnapTime` 可选「删列」或 `DateTime?`；`GoodsWeight` → `decimal?`。表为历史**只读**（D19 无新 Insert）。
- 现状：`GovSyncData.SnapTime` / `GoodsWeight` 为 `string?`；Fluent `HasMaxLength`；`GovSyncDataDto` 同为 string。
- 约束：禁止 tuple；D5 outbound payload 不改；Mode B 仅 UrbanManagement；AccessCode / SiteType 不在本 change。

## Goals / Non-Goals

**Goals:**

- 只读表两列与主实体时间/重量语义对齐（`DateTime?` / `decimal?`）。
- 历史数据尽量保留；无法解析置 NULL。

**Non-Goals:**

- 删除 `SnapTime` 列或整表废弃。
- 改 `GovSyncWeightPayload` / `GovRequestWeightDto` 等政府协议字段。
- `GovSyncData.SiteType` → enum；`BuildLicenseNo` 改名。
- 恢复写入或迁移历史行到 `UrbanWeighingRecord`。

## Decisions

### 1. SnapTime 保留为 DateTime?（T1）

- **选择**：列保留，类型 `DateTime?`；**不删列**。
- **理由**：只读查询仍需要时间过滤/展示；删列丢失可恢复信息。

### 2. GoodsWeight → decimal?

- **选择**：`decimal?`（与 `UrbanWeighingRecord.TotalWeight` 一致量级语义：历史存的是货物重量数字字符串）。
- **理由**：P3 明确要求；NULL 表示缺失或无法解析。

### 3. Migration parse 策略

- **SnapTime**：优先 `yyyy-MM-dd HH:mm:ss` / ISO-ish；失败 → NULL（不抛）。
- **GoodsWeight**：InvariantCulture `decimal.TryParse`；去空白；失败 → NULL。
- **实现**：SQLite 上可先 SQL `UPDATE` 到临时列或用 EF raw SQL + 应用层脚本；优先 **migration SQL + 二次 AlterColumn**，复杂格式可用一次性 data fix SQL。
- **备选**：仅改 CLR、列仍 TEXT — 拒绝（与强类型目标不符）。

### 4. DTO / API

- **选择**：`GovSyncDataDto.SnapTime` = `DateTime?`，`GoodsWeight` = `decimal?`；`FromEntity` 直接赋值。
- **BREAKING**：JSON 由字符串变为日期/数字。

### 5. 不改 outbound / Legacy wire

- **选择**：`GovSyncWeightPayload`、`GovRequestWeightDto` 保持 `string?`。
- **理由**：D5；Legacy 已 WIP 不入库。

## Risks / Trade-offs

- **[Risk] 解析失败丢精度** → 接受 NULL；可在 migration 前抽检样例格式。
- **[Trade-off] API BREAKING** → 仅 UM 内部只读消费；同版本部署。
- **[Risk] SQLite AlterColumn 局限** → 沿用本 initiative 既有 PRAGMA / rebuild 模式。

## Migration Plan

1. 备份 SQLite。
2. Parse UPDATE → AlterColumn（TEXT→合适类型）。
3. 部署 UM；启动 `MigrateAsync`。
4. 回滚：restore backup。

## Open Questions

- 无阻塞项（T1 已定为保留 `DateTime?`）。
