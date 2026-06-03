## 1. 模块与配置

- [x] 1.1 在 `MaterialClient.Urban.csproj` 确认/添加 `Volo.Abp.BackgroundWorkers`（或经 Common 传递的等效包引用）
- [x] 1.2 `MaterialClientUrbanModule` 增加 `[DependsOn(typeof(AbpBackgroundWorkersModule))]`
- [x] 1.3 在 `appsettings.json`（及示例配置）添加 `BackgroundServices:Polling`、`Urban:UploadPollingPeriodMs`、`Urban:UploadBatchSize` 默认值
- [x] 1.4 当 `BackgroundServices:Polling == true` 时 `AddBackgroundWorkerAsync<MaterialClient.Urban.Backgrounds.PollingBackgroundService>()`；为 `false` 时不注册

## 2. PollingBackgroundService 实现

- [x] 2.1 新建 `MaterialClient.Urban/Backgrounds/PollingBackgroundService.cs`，继承 `AsyncPeriodicBackgroundWorkerBase`
- [x] 2.2 构造函数从 `IConfiguration` 读取 `Urban:UploadPollingPeriodMs` 设置 `Timer.Period`（默认 600000）
- [x] 2.3 实现 `DoWorkAsync`：`IUnitOfWorkManager.WithUow` 内调用 `GetPendingForUploadAsync`（limit = `Urban:UploadBatchSize`，默认 50）
- [x] 2.4 遍历结果：跳过 `IsAnomaly`；对每条 `await IUrbanServerUploadService.SubmitRecordAsync(weighingRecordId)`；单条 catch 记日志并继续
- [x] 2.5 确认不引用 `MaterialClient.Backgrounds` 或 `MaterialClientModule` 类型

## 3. 审批路径修正

- [x] 3.1 在 `UrbanAttendedWeighingViewModel.ApproveRecordAsync`（或 `ApproveRecordCommand` 实现）移除审批成功后的即时 `SubmitRecordAsync`
- [x] 3.2 确认 `UpdateWeighingRecordAsync` 仍将 `SyncStatus` 复位为 `Pending`（既有行为保持不变）
- [x] 3.3 手动验证：审批后记录为 Pending，待 Worker 周期后变为 Synced（或 Failed 并写日志）

## 4. 验证

- [x] 4.1 `dotnet build` MaterialClient.Urban 解决方案配置通过
- [x] 4.2 关闭 `BackgroundServices:Polling` 时 Worker 不启动；开启后日志可见周期性 `DoWorkAsync`
- [x] 4.3 异常记录（`IsAnomaly == true`）保持 Pending 且不被 Worker 上传
- [x] 4.4 运行 `openspec verify`（或项目约定的 AGENTS 门禁）确认本 change delta 与实现一致
