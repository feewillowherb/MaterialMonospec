# Proposal: MaterialClient 代码整洁性与 Trait 合规收口

## Why

在完成数据库迁移隔离后，对 `repos/MaterialClient` 的全仓代码评审发现 2 类低风险历史残留：
1. **Trait 违规残留**：2 个 ViewModel 仍通过 `IServiceProvider` 直接解析 `IRepository`（违反 `viewmodel-no-repository`），其中 `AttendedWeighingDetailViewModelBase` 还保留了一个完全未使用的 `_waybillRepository` 字段；2 个私有辅助方法仍返回 C# ValueTuple（违反「Record 替代 Tuple」）。
2. **仓库根目录遗留物**：已废弃的 `.specify/`（旧 SpecKit 模板与脚本）与 `archive/`（历史文档归档包）仍被 Git 跟踪，且本地存在未跟踪临时目录/文件（`popup-diag.log`、`.build-verify/`、遗留空目录 `openspec/`）。

各产品独立的 EF Core `Migrations/` 仍属正常演进资产，不在本次清理范围内。

## What Changes

- **ViewModel 层去除 Repository 依赖**：
  - 在 `IWeighingRecordService` / `WeighingRecordService` 新增 `GetWeighingRecordAsync(long id)` 与 `DeleteWeighingRecordAsync(long id)`（均标注 `[UnitOfWork]`），在 `AttendedWeighingDetailViewModelBase` 改调 `IWeighingRecordService`，同时移除未使用的 `_waybillRepository` 字段。
  - 在 `IProviderService` / `ProviderService` 新增 `FindByIdAsync(int id)`（标注 `[UnitOfWork]`），在 `ManualMatchWindowViewModel` 改调 `IProviderService`。
- **Record 替代 Tuple**：
  - `ImageViewerWindow.axaml.cs` 的 `GetFitMaxSize` 改返回命名 `FitMaxSize` record。
  - `HikvisionLprService.cs` 的 `ParseUrl` 改返回命名 `ParsedListenEndpoint` record。
- **根目录遗留清理**：
  - 从 `repos/MaterialClient` 移除已跟踪的历史目录 `.specify/` 与 `archive/`。
  - 清理本地未跟踪的 `popup-diag.log`、`.build-verify/` 与空目录 `openspec/`。

## Capabilities

### New Capabilities

- `materialclient-code-hygiene`: 约束 MaterialClient 界面层数据访问边界、命名 Record 替代 Tuple 与仓库根目录整洁性。

## Impact

- 仅影响 `repos/MaterialClient` 子仓库（6 个 C# 文件 + 根目录 `.specify/`、`archive/`）。
- 零外部 API / 数据库 Schema / 业务行为变更。
