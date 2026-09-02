## 1. Branch & setup

- [x] 1.1 在 `repos/UrbanManagement` 自 `dev-urban-entity-semantic` 创建并切换分支 `refactor-urban-entity-sync-status-enum`（Mode B；已 squash 回 `dev-*`）
- [x] 1.2 阅读 [`docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md`](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md) P0 与 [`design.md`](./design.md)

## 2. Entity & EF migration

- [x] 2.1 `UrbanPassageRecord.SyncType`: `int?` → non-nullable `SyncStatus`
- [x] 2.2 `UrbanWeighingRecord`: `SyncType` / `ClientSyncType` non-nullable；`RetryCount` / `ClientRetryCount` non-nullable `int`
- [x] 2.3 `GovSyncData`: `SyncType` → `SyncStatus`；`SyncNumber` → `RetryCount`（删除 `SyncNumber` 属性）
- [x] 2.4 `UrbanPassageRecord.ResetGovSync` / `FromReceive` 使用 `SyncStatus.Pending`
- [x] 2.5 新增 EF migration：NULL 回填、`SyncNumber` rename、non-nullable 约束
- [x] 2.6 更新 `UrbanManagementDbContext` 配置（如需 enum conversion）

## 3. Services & managers

- [x] 3.1 `GovSyncManager` / `GovCheckpointSyncManager` / `GovProductSyncManager`：消除 `0/1/2`，改用 `SyncStatus`
- [x] 3.2 `UrbanWeighingRecordAppService` / passage AppServices：enum 赋值与 Reset 逻辑
- [x] 3.3 确认 Modern 路径无 `GovSyncData.InsertAsync`

## 4. Legacy WIP

- [x] 4.1 `LegacyGovSyncAppService`：移除全部落库逻辑
- [x] 4.2 `LegacyApiController`：返回 HTTP 501 + WIP `ApiResultDto`；标记 WIP/Obsolete
- [x] 4.3 确认无 `UrbanWeighingRecord` / `GovSyncData` Insert

## 5. DTO & API serialization

- [x] 5.1 DTO `SyncType` / `ClientSyncType` 改为 `SyncStatus`；`ClientRetryCount` non-nullable
- [x] 5.2 配置 `JsonStringEnumConverter`（或等价）使 API 输出字符串 enum 名
- [x] 5.3 更新 `GovSyncDataDto` 等与 GovSyncData 相关的映射

## 6. Blazor UI

- [x] 6.1 称重 / 卡口 / 成品列表：`CanResetSync` 等条件改用 `SyncStatus` / 字符串 enum
- [x] 6.2 同步状态展示适配字符串 enum API 响应

## 7. Tests & verify

- [x] 7.1 更新/新增 Core.Tests：passage reset、manager 选行、Legacy 501 无落库
- [x] 7.2 `dotnet build` / 相关测试通过
- [x] 7.3 本 change `tasks.md` 全部勾选

## 8. Monospec（本仓）

- [x] 8.1 确认 OpenSpec 工件与实现一致
- [ ] 8.2 准备 archive（用户确认后）

**后续 change（不在本 tasks 范围）**：`remove-gov-project-fd-build-license-no`、`refactor-urban-proid-guid-required`、`update-urban-weighing-record-site-type-enum`、`rename-gov-project-enable-sync-to-is-sync-enabled`；intake [INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)、[INT-006](../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md)。
