## Why

Urban 称重记录的上传管线（`GetPendingForUploadAsync` + `IUrbanServerUploadService.SubmitRecordAsync`）已在领域层就绪，但 **MaterialClient.Urban 未注册任何周期性 Background Worker** 来扫描 `SyncStatus == Pending` 并上云。审批流程在 `UpdateWeighingRecordAsync` 复位 Pending 后仍可能在 UI 路径 **立即调用** `SubmitRecordAsync`，与 epic/架构约定（与主程序 `PollingBackgroundService` 同形态：`AsyncPeriodicBackgroundWorkerBase` + `WithUow`）不一致。需要在 Urban 工程内实现 **独立的** `PollingBackgroundService`，打通 Pending 称重记录的后台重传，并修正审批后的上传触发方式。

## What Changes

- 在 `MaterialClient.Urban/Backgrounds/` 新增 Urban 专用 **`PollingBackgroundService`**（`AsyncPeriodicBackgroundWorkerBase`，在 `IUnitOfWorkManager.WithUow` 内执行上传逻辑；**不**引用或注册主程序 `MaterialClient/Backgrounds/PollingBackgroundService`）。
- **`MaterialClientUrbanModule`**：依赖 `AbpBackgroundWorkersModule`；当配置 `BackgroundServices:Polling` 为 `true` 时注册 Urban 的 `PollingBackgroundService`。
- Worker **`DoWorkAsync`**：调用 `IUrbanWeighingExtensionService.GetPendingForUploadAsync` 获取待上传扩展，跳过 `IsAnomaly == true` 的记录，对每条调用 `IUrbanServerUploadService.SubmitRecordAsync`；单条失败记录日志并继续，不阻塞整批。
- **`UrbanAttendedWeighingViewModel.ApproveRecordAsync`**：审批保存后 **仅** 依赖 `UpdateWeighingRecordAsync` 将 `SyncStatus` 复位为 `Pending`；**移除** UI 线程上的立即 `SubmitRecordAsync`。
- **配置**：复用/对齐 `BackgroundServices:Polling` 开关；周期与批量上限在 `appsettings` 的 Urban 或 BackgroundServices 节定义（具体键名见 design.md）。
- **规范增量**：更新 `urban-abp-module`（允许注册 Urban 自有 Worker，仍禁止主程序 Worker）；新增 `urban-polling-background-service` 能力 spec；更新 `weighing-record-approval`（明确审批不触发即时 HTTP 上传）。

## Capabilities

### New Capabilities

- `urban-polling-background-service`: Urban 客户端周期性轮询上传 Pending 称重记录至 UrbanManagement，含模块注册、Worker 行为、配置开关与异常记录跳过规则。

### Modified Capabilities

- `urban-abp-module`: 将「不得注册 PollingBackgroundService」细化为不得注册 **主程序** `MaterialClient.Backgrounds.PollingBackgroundService`；允许在 `BackgroundServices:Polling` 启用时注册 **Urban 工程内** 的 `MaterialClient.Urban.Backgrounds.PollingBackgroundService`。
- `weighing-record-approval`: 审批成功路径 MUST NOT 在 UI 线程同步调用 `IUrbanServerUploadService.SubmitRecordAsync`；上传由后台 Worker 负责。

## Impact

| 区域 | 说明 |
|------|------|
| `MaterialClient.Urban` | 新 `Backgrounds/PollingBackgroundService.cs`；`MaterialClientUrbanModule.cs`；`UrbanAttendedWeighingViewModel.cs`；`appsettings.json` |
| `MaterialClient.Common` | 无行为变更；复用 `IUrbanWeighingExtensionService`、`IUrbanServerUploadService` |
| `MaterialClient`（主程序） | 无变更；Urban 不得依赖 `MaterialClientModule` |
| `UrbanManagement` | 无 API 变更；消费既有称重提交接口 |
| OpenSpec | `urban-abp-module`、`weighing-record-approval` delta；新 `urban-polling-background-service` |
