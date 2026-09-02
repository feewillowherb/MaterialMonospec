## Why

UrbanManagement 实体与 Service 层对「政府同步状态」存在三种表达（`SyncStatus?` enum、`int?` 魔法值、`0/1/2` 字面量），RetryCount 与 GovSyncData.SyncNumber 命名分裂，API 仍可能输出数字 enum。Legacy HTTP 路径仍双写 `UrbanWeighingRecord` + `GovSyncData`，与 Modern 单写模型冲突。调研结论见 [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/`](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/00-调研总览.md)（P0 范围）。

## What Changes

- 全路径 `SyncType` 统一为 non-nullable `SyncStatus` enum（`UrbanWeighingRecord`、`UrbanPassageRecord`、`GovSyncData` 表结构）。
- `RetryCount` / `ClientRetryCount` 收紧为 non-nullable `int`；`GovSyncData.SyncNumber` 合并为 `RetryCount`（EF migration）。
- API / Blazor 消费方：`SyncStatus` JSON 序列化为 **字符串 enum 名**（`Pending` / `Success` / `Failed`）。
- Service / Entity 消除全部 `SyncType` 魔法值；`ResetGovSync` 等类型归属方法使用 enum。
- **Legacy HTTP 业务移除**：`LegacyApiController` / `LegacyGovSyncAppService` 标记 WIP，**不入库**；返回明确未实现响应（**BREAKING**）。
- **停止 GovSyncData 双写**：移除一切新 `GovSyncData` Insert；Modern 路径仅写 `UrbanWeighingRecord`。
- Git：**Mode B** — initiative 基线 `dev-urban-entity-semantic`（`UrbanManagement` 仓；change 分支 `refactor-urban-entity-sync-status-enum` squash 入 `dev-*`；initiative 收尾再 promote 入 trunk）。

**本 change 不包含**（后续独立 change / intake）：`ProId` required Guid、`SiteType` enum、`IsSyncEnabled` 改名、移除 `FdBuildLicenseNo`、AccessCode 重命名（[INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)）。

## Capabilities

### New Capabilities

- `urban-entity-sync-status`: 跨实体的 `SyncStatus` / `RetryCount` 领域模型、API 字符串 enum 序列化、GovSyncData 停写与 Schema 收敛。

### Modified Capabilities

- `gov-sync-worker`: 待选/成功/失败判定改用 `SyncStatus` enum，禁止 int 魔法值。
- `legacy-api-compat`: Legacy 端点 WIP、不入库、不双写 GovSyncData（**BREAKING**）。
- `urban-passage-reset-sync`: Reset 与 UI 条件改用 `SyncStatus` enum 名。
- `urban-weighing-api`: `SyncType` / `ClientSyncType` enum 化、non-nullable、`ClientRetryCount` non-nullable、API 字符串 enum。

## Impact

- **UrbanManagement**：`UrbanManagement.Core` Entities、DTOs、Managers、AppServices、EF migrations、Blazor 列表页、`UrbanManagement.Core.Tests`。
- **MaterialClient / FdSoft.BasePlatform**：无变更（本 change）。
- **历史 `GovSyncData` 行**：只读保留；schema 随 migration 更新，无新写入。
