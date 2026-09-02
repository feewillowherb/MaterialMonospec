## Context

- `UrbanPassageRecord` 已有 `SyncType`（0 待同步 / 1 成功 / 2 失败）、`RetryCount`、`SyncTime`、`LastErrorTime`。
- 卡口、成品各自独立 ApplicationService（`UrbanCheckpointPassageAppService`、`UrbanFinishedProductPassageAppService`），列表页只读展示同步状态。
- 称重侧参考实现：`UrbanWeighingRecordAppService.ResetSyncAsync` + `WeighingRecord.razor` 按钮；TEMP 允许 SyncType 1 或 2 重置，注释标明下版本可能收紧为仅失败。
- Gov 出队：`GovCheckpointSyncManager` / `GovProductSyncManager` 查询 `SyncType != 1` 且 `RetryCount < maxRetryCount`，Reset 置 0 即可重新入队。

## Goals / Non-Goals

**Goals:**

- 卡口、成品列表页均可对单条记录手动重置同步。
- API 与 UI 行为与称重 ResetSync 对齐（除无异常/审批校验）。
- 每条通道 AppService 校验 `PassageSource`，防止跨通道误操作。
- 测试可验证状态变更与拒绝路径。

**Non-Goals:**

- 不修改 MaterialClient 上云或重试逻辑。
- 不批量重置、不新增 Gov Worker 配置。
- 不把 ResetSync 抽到共享 Passage 基类 Service（保持两入口独立，与 Receive 对称）。
- 本期不收紧为「仅失败可重置」（与称重 TEMP 一致）。

## Decisions

### 1. 共用 Input DTO，分 Service 实现

- **选择**：`UrbanPassageResetSyncInputDto { Guid Id }` 放在 `UrbanPassageDtos.cs`；`ResetSyncAsync` 分别在 checkpoint / finished-product AppService 中实现。
- **理由**：与现有 Receive 双入口一致；各 Service 内校验 `PassageSource`，避免单一方法 + source 参数。
- **备选**：抽象 `UrbanPassageAppServiceBase` — 拒绝，YAGNI。

### 2. 状态变更放在实体方法

- **选择**：在 `UrbanPassageRecord` 增加 `ResetGovSync()` 实例方法，设置 `SyncType = 0`、`RetryCount = 0`（可选清 `LastErrorTime` 否 — 与称重一致仅改两字段）。
- **理由**：遵循 type-owned-methods；Service 不逐字段赋值。

### 3. 可重置条件（TEMP，对齐称重）

- **选择**：`SyncType is 1 or 2` 允许；`SyncType` 为 0 或 null 抛 `BusinessException`（待同步无需重置）。
- **理由**：与 `UrbanWeighingRecordAppService` 及 `WeighingRecord.razor` 的 `CanResetSync` 一致，便于运营补报已成功记录。

### 4. UI 对称实现

- **选择**：两页增加「操作」列；`CanResetSync(UrbanPassageListItemDto)` 与称重相同条件；确认后调用对应 AppService，刷新列表；行级 loading + 页顶错误条（可复制称重页模式）。
- **理由**：最小 diff，用户已熟悉称重交互。

### 5. 返回 DTO

- **选择**：`ResetSyncAsync` 返回 `UrbanPassageListItemDto`（无大图时可不带 `LargeImageBase64` 或复用 `FromEntity(record, null)`）。
- **理由**：列表刷新可局部更新或整表 reload；与 weighing 返回 output DTO 对称。

## Risks / Trade-offs

- **[Risk] 误重置已成功且政府侧不可重复的记录** → 与称重相同 TEMP 策略；注释保留 TEMP，后续 change 可统一收紧。
- **[Risk] 跨通道 Id 调用** → Service 内校验 `PassageSource`，不匹配则 `NotFound` 或 `InvalidSource` BusinessException。
- **[Trade-off] 两 AppService 重复 Reset 逻辑** → 可接受，与 Receive/GetList 重复模式一致；不为此引入 DI Service。

## Migration Plan

- 无数据库 migration（字段已存在）。
- 部署 UM 后即可使用；无需客户端配合。
- 回滚：移除 API 与 UI 按钮即可，不影响已存数据。

## Open Questions

- 无。若产品要求「仅失败可重置」，另开 change 与称重一并收紧。
