## 1. OpenSpec 校验

- [x] 1.1 验证 OpenSpec 变更 `refactor-cleanup-materialclient-hygiene` 通过 `openspec validate refactor-cleanup-materialclient-hygiene --strict`

## 2. ViewModel 去除 Repository 依赖

- [x] 2.1 在 `IWeighingRecordService` / `WeighingRecordService` 新增 `GetWeighingRecordAsync` 与 `DeleteWeighingRecordAsync`（标注 `[UnitOfWork]`），更新 `AttendedWeighingDetailViewModelBase` 改调 `IWeighingRecordService` 并移除未使用的 `_waybillRepository`
- [x] 2.2 在 `IProviderService` / `ProviderService` 新增 `FindByIdAsync`（标注 `[UnitOfWork]`），更新 `ManualMatchWindowViewModel` 改调 `IProviderService`

## 3. Record 替代 Tuple

- [x] 3.1 将 `ImageViewerWindow.axaml.cs` 的 `GetFitMaxSize` 改为返回命名 `FitMaxSize` record
- [x] 3.2 将 `HikvisionLprService.cs` 的 `ParseUrl` 改为返回命名 `ParsedListenEndpoint` record

## 4. 清理根目录历史遗留

- [x] 4.1 从 `repos/MaterialClient` 移除已跟踪的 `.specify/` 与 `archive/`，并清理本地未跟踪杂物（`popup-diag.log`、`.build-verify/`、空目录 `openspec/`）

## 5. 构建与合规验证

- [x] 5.1 全量构建 `MaterialClient.sln` 并运行单元测试，复扫确认 `ViewModels`/`Views` 0 `IRepository`、0 C# Tuple 残留且各产品 `Migrations/` 完整保留
