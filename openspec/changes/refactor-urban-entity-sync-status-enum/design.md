## Context

- 调研：[docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)（D1–D2、D9–D11、D18–D19）。
- 现状：`UrbanWeighingRecord` 已部分使用 `SyncStatus?`；`UrbanPassageRecord` / `GovSyncData` 为 `int?`；`GovProductSyncManager` 等使用 `SyncType != 1`；Legacy 双写 `GovSyncData`。
- 已有 enum：`UrbanManagement.Core.Entities.Enums.SyncStatus`（`Pending=0, Success=1, Failed=2`）。
- 约束：`BuildLicenseNo` / `AccessCode` 挂起（INT-005）；Outbound `GovSyncWeightPayload` 不改；禁止 tuple；type-owned-methods；无 DB FK。

## Goals / Non-Goals

**Goals:**

- 单一同步状态词汇表：`SyncStatus` enum，创建时默认 `Pending`。
- Retry 计数统一：`RetryCount` non-nullable；GovSyncData 废弃 `SyncNumber` 列。
- API 对外 `SyncStatus` 为 JSON 字符串名。
- Legacy 路径 WIP、零落库；停止 GovSyncData 新 Insert。
- EF migration 处理 NULL → 默认值。

**Non-Goals:**

- `ProId` required Guid、`SiteType`→`UrbanSiteType`、`EnableSync`→`IsSyncEnabled`、删 `FdBuildLicenseNo`（后续 change）。
- Legacy 完整兼容层（[INT-006](../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)）。
- AccessCode 重命名、MaterialClient 变更。
- GovSyncData 历史行 ETL 或删表。

## Decisions

### 1. Entity 字段形态

- **选择**：`SyncStatus SyncType { get; set; } = SyncStatus.Pending`（non-nullable）；`int RetryCount { get; set; }`；称重侧 `ClientSyncType` / `ClientRetryCount` 同上。
- **理由**：与调研 D2/D9/D11 一致；创建路径显式赋值，migration 回填 NULL。
- **备选**：保留 nullable — 拒绝，Service guard 过多。

### 2. GovSyncData.SyncNumber → RetryCount

- **选择**：EF migration `RenameColumn`（SQLite `RenameColumn` 或等价 rebuild）；代码删除 `SyncNumber` 属性。
- **理由**：D9 统一语义；GovSyncData 不再新写入，仅 schema 对齐。

### 3. API JSON：字符串 enum

- **选择**：对 `SyncStatus` 使用 `JsonStringEnumConverter`（全局或 Urban API 命名策略范围内）；Blazor 与 MaterialClient **本 change 不修改** — 仅 UM API 输出与 UM Blazor 消费对齐。
- **理由**：D10；避免前端依赖 0/1/2。
- **备选**：继续 int — 拒绝。

### 4. Legacy WIP 响应

- **选择**：`POST /Api/Post` 保留路由；**HTTP 501**，body 仍为 legacy `ApiResultDto` 形状：`{ "success": false, "msg": "WIP: legacy endpoint unavailable", "code": 501, "data": null }`；删除 `LegacyGovSyncAppService` 内全部 Insert/Receive 调用。
- **理由**：明确 BREAKING；旧客户端可识别失败；不入库（D18）。
- **备选**：410 Gone — 未选，501 更贴近「未实现」。

### 5. 停止 GovSyncData 双写

- **选择**：删除 Legacy 与 Modern 路径中一切 `_govSyncDataRepository.InsertAsync`；Modern 仅 `UrbanWeighingRecord` + 附件；GovSyncData DbSet 保留供历史只读查询（若有 UI/诊断）。
- **理由**：D19；与 INT-006 方向一致。

### 6. Passage / Weighing Manager 与 Reset

- **选择**：`GovCheckpointSyncManager` / `GovProductSyncManager` / `GovSyncManager` 比较 `SyncStatus.Success` / `Pending` / `Failed`；`UrbanPassageRecord.ResetGovSync()` 设 `SyncStatus.Pending`（type-owned）。
- **理由**：消除魔法值；与 urban-passage-reset-sync spec 对齐后 archive。

### 7. Migration 数据回填

- **选择**：`SyncType` NULL → `0`（Pending）；`RetryCount` NULL → `0`；`ClientRetryCount` NULL → `0`；Passage `SyncType` int 1/2 映射为 enum 值不变。
- **理由**：SQLite INTEGER 列类型不变，仅语义收紧。

## Risks / Trade-offs

- **[Risk] Legacy 旧 GovClient 立即不可用** → 文档 + INT-006；WIP msg 明确；运营已知 Modern 路径。
- **[Risk] Blazor / API 字符串 enum 与旧 UI 假设 int** → 本 change 同步改 UM Blazor 列表与 DTO；加 Core.Tests。
- **[Risk] 归档 spec 中大量 `SyncType=1` 表述** → delta spec 全量 MODIFIED 关键 Requirement。
- **[Trade-off] GovSyncData 表空转** → 接受；P3 或 INT-006 再收敛。

## Migration Plan

1. 部署 EF migration（SyncType 非空默认、RetryCount 非空、SyncNumber rename）。
2. 部署应用：Legacy 501；Worker/Manager 使用 enum。
3. 验证：无新 GovSyncData 行；API JSON 为字符串 enum。
4. 回滚：revert migration + 代码；Legacy 恢复需另 change（不推荐）。

## Open Questions

- 无（Legacy 501、字符串 enum 已在调研批次三前确认）。
