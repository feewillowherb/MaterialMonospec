## Why

UrbanManagement 称重列表已支持「重置同步」，可将政府同步失败或已成功记录重新置为待同步并由 Gov Worker 再次出队。卡口与成品进出页目前仅展示同步状态，运营无法手动重试，失败或需补报时只能改库或等待客户端重复上云。

## What Changes

- 为 `UrbanCheckpointPassageAppService` 与 `UrbanFinishedProductPassageAppService` 各增加 `ResetSyncAsync`，按记录 Id 将 `SyncType` 置为 `0`、`RetryCount` 置为 `0`。
- 新增 `UrbanPassageResetSyncInputDto`（单条 `Id`），两通道共用；返回更新后的 `UrbanPassageListItemDto`。
- 卡口页 `CheckpointPassage.razor`、成品页 `FinishedProductPassage.razor` 增加「重置同步」操作列，交互与称重页对称（含 loading / 错误提示）。
- 行为与称重 TEMP 规则一致：当前允许 `SyncType` 为成功(1)或失败(2)时重置；待同步(0)拒绝；进出无审批/异常 gate。
- 单元测试覆盖两 AppService 的成功、失败、待同步拒绝场景。
- Git：**Mode A**（UrbanManagement 仓自 trunk 切同名分支 `add-urban-passage-reset-sync`，squash 回 trunk）。

## Capabilities

### New Capabilities

- `urban-passage-reset-sync`: UM 卡口与成品 passage 记录的手动重置同步 API、UI 与校验规则。

### Modified Capabilities

（无 — 不修改 MaterialClient 或 Gov Worker 出队逻辑；Reset 仅改实体 sync 字段，现有 `GovCheckpointSyncManager` / `GovProductSyncManager` 已按 `SyncType != 1` 拾取待同步行。）

## Impact

- **UrbanManagement**：`UrbanPassageDtos.cs`、两个 Passage AppService、两个 Blazor 列表页、`UrbanManagement.Core.Tests`。
- **MaterialClient / FdSoft.BasePlatform**：无变更。
- **Gov Sync Worker**：无代码变更；重置后下一周期自动重试出队。
