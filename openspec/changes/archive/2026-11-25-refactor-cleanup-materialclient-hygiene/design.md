# Design: MaterialClient 代码整洁性与 Trait 合规收口

## 1. ViewModel 数据访问边界收口（`viewmodel-no-repository`）

### 1.1 `AttendedWeighingDetailViewModelBase`
- **现状**：持有 `_weighingRecordRepository`（仅用于 `DeleteAsync(_listItem.Id)` 与 `GetAsync(_listItem.Id)`）以及完全未使用的 `_waybillRepository`。
- **改造**：
  - 在 `IWeighingRecordService` 中补充：
    - `Task<WeighingRecord> GetWeighingRecordAsync(long id);`
    - `Task DeleteWeighingRecordAsync(long id);`
  - 在 `WeighingRecordService` 中以 `[UnitOfWork] public virtual async Task` 实现上述两个方法，复用已注入的 `_weighingRecordRepository`。
  - 在 `AttendedWeighingDetailViewModelBase` 中移除 `_weighingRecordRepository`、`_waybillRepository` 及 `using Volo.Abp.Domain.Repositories;`，改为解析 `IWeighingRecordService`。

### 1.2 `ManualMatchWindowViewModel`
- **现状**：仅在 `LoadProviderNameAsync` 中通过 `_providerRepository.GetAsync(CurrentRecord.ProviderId.Value)` 查询供应商名称。
- **改造**：
  - 在 `IProviderService` 中补充 `Task<Provider?> FindByIdAsync(int id);`，在 `ProviderService` 中以 `[UnitOfWork] public virtual async Task<Provider?> FindByIdAsync(int id)` 调用 `_providerRepository.FindAsync(id)`。
  - 在 `ManualMatchWindowViewModel` 中移除 `_providerRepository` 及 `using Volo.Abp.Domain.Repositories;`，改为解析 `IProviderService`。

## 2. Record 替代 Tuple

- `ImageViewerWindow.axaml.cs`：定义 `private sealed record FitMaxSize(double Width, double Height);`，替换 `GetFitMaxSize(ScrollViewer)` 的 `(double w, double h)` 返回值。
- `HikvisionLprService.cs`：定义 `private sealed record ParsedListenEndpoint(string Ip, int Port);`，替换 `ParseUrl(string)` 的 `(string ip, int port)` 返回值。

## 3. 仓库根目录遗留清理

- 通过 `git rm -r` 移除 `repos/MaterialClient/.specify/` 与 `repos/MaterialClient/archive/`。
- 删除本地未跟踪的 `repos/MaterialClient/popup-diag.log`、`repos/MaterialClient/.build-verify/` 与空目录 `repos/MaterialClient/openspec/`。
- 保留各产品独立维护的 `Migrations/` 目录不做任何改动。
