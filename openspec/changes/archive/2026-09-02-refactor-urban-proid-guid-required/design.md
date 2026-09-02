## Context

- 调研 P2：[04 §P2 ProId](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)（D12、D14）。
- 前置：P0/P1 已在 `dev-urban-entity-semantic`；`GovProject.Id` 已为 `Guid`；`LicenseInfo.ProjectId` 已为 required `Guid`。
- 现状：`UrbanWeighingRecord.ProId` / `UrbanPassageRecord.ProId` 为 `Guid?`；`ClientOnlineStatus.ProId` 为 `string`；`GovSyncData.ProId` 为 `string?`；Submit DTO 为 `Guid?`。
- 约束：禁止 tuple；type-owned-methods；no-database-fk；wire JSON camelCase 保持。

## Goals / Non-Goals

**Goals:**

- 持久化 Entity 层 `ProId` 统一为 non-nullable `Guid`（含只读 `GovSyncData` schema）。
- 创建/Receive/Upload 边界拒绝 `Guid.Empty` 与缺失 `ProId`。
- 在线态表 `string` → `Guid` 列类型迁移。
- SignalR JSON `proId` 仍为 string；服务端 parse + validate。

**Non-Goals:**

- `SiteType`、`IsSyncEnabled`（独立 change）。
- AccessCode / BuildLicenseNo 改名（INT-005）。
- 修复或回填 D14 非法在线态行的业务含义。
- Legacy HTTP 落库（仍 WIP）。

## Decisions

### 1. Nullable → required Guid（业务实体）

- **选择**：`UrbanWeighingRecord` / `UrbanPassageRecord` 使用 `Guid ProId`；migration 将现有 `NULL` 回填为 `Guid.Empty`，再加 non-nullable 约束；**新写入** Service 拒绝 `Empty`。
- **理由**：与 D12 一致；历史 NULL 极少，Empty 作 tombstone 便于识别脏数据。
- **备选**：删 NULL 行 — 拒绝，数据丢失风险。

### 2. 在线态 string → Guid

- **选择**：`ClientOnlineStatus` / `ClientDeviceOnlineStatus`.`ProId` 改为 `Guid`；migration 仅保留 `Guid.TryParse` 成功的行，**删除**无法解析的行（D14 忽略）。
- **理由**：D14 明确不修复非法历史；删除比保留 string 列更干净。
- **备选**：保留 string 列 — 拒绝，与 D12 全仓 Guid 冲突。

### 3. GovSyncData 只读表

- **选择**：列类型改为 `Guid`（SQLite rebuild）；`TryParse` 成功则转换，否则写 `Guid.Empty`；**无**新 Insert 路径变更。
- **理由**：schema 对齐；只读表 Empty 不影响 Modern 路径。

### 4. API 边界校验

- **选择**：`UrbanWeighingRecordAppService.ReceiveAsync` / passage receive：`ProId == Guid.Empty` 或缺失 → `BusinessException` 或 validation error。
- **理由**：fail-fast，避免 silent 脏数据。

### 5. MaterialClient 上云

- **选择**：`SubmitRecordAsync` / passage upload：无有效 `LicenseInfo.ProjectId` 时 **不上传** 并 log warning（或 throw，与现有 license gate 一致）。
- **理由**：D12 客户端必填；授权门控已保证正常路径有 ProjectId。

### 6. SignalR wire 形状

- **选择**：`DeviceStatusMessage.ProId` 保持 **string** JSON；Hub 在 upsert DB 前 `Guid.TryParse`，失败则 skip 持久化并 log（不写在线态）。
- **理由**：避免跨端 JSON breaking；DB 层强类型。

## Risks / Trade-offs

- **[Risk] 删除非法在线态行** → 仅影响无法 parse 的脏数据；合法 Guid string 行保留。
- **[Risk] 历史称重 NULL ProId 变为 Empty** → 查询需过滤 Empty；新记录必须合法 Guid。
- **[Risk] BREAKING Receive API** → MaterialClient 已传 ProId；需联调验证。

## Migration Plan

1. 备份 SQLite（UrbanManagement）。
2. 应用 migration：在线态删脏行 → 改 Guid 列；称重/通行 NULL→Empty；GovSyncData string→Guid。
3. 部署 UM + MaterialClient 同版本。
4. 回滚：restore DB backup。

## Open Questions

- 无阻塞项。
