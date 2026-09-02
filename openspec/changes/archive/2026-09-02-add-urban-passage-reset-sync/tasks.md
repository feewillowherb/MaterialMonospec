## 1. UrbanManagement — 领域与 DTO

- [x] 1.1 在 `UrbanPassageRecord` 增加 `ResetGovSync()` 实例方法（`SyncType = 0`，`RetryCount = 0`）
- [x] 1.2 在 `UrbanPassageDtos.cs` 增加 `UrbanPassageResetSyncInputDto`

## 2. UrbanManagement — ApplicationService

- [x] 2.1 `IUrbanCheckpointPassageAppService` / 实现类增加 `ResetSyncAsync`：校验 Id、PassageSource=Checkpoint、TEMP 允许 SyncType 1/2
- [x] 2.2 `IUrbanFinishedProductPassageAppService` / 实现类增加同名方法，校验 PassageSource=FinishedProduct
- [x] 2.3 两方法返回 `UrbanPassageListItemDto.FromEntity(record, null)`，使用 `[UnitOfWork]`

## 3. UrbanManagement — Blazor UI

- [x] 3.1 `CheckpointPassage.razor`：操作列、`CanResetSync`、`ResetSyncAsync`、行级 loading 与错误提示，成功后刷新列表
- [x] 3.2 `FinishedProductPassage.razor`：同上，调用 finished-product AppService

## 4. UrbanManagement — 测试

- [x] 4.1 新增 `UrbanCheckpointPassageAppServiceTests`（或扩展现有测试文件）：成功/失败可重置、待同步拒绝、错误 Source 拒绝
- [x] 4.2 新增 `UrbanFinishedProductPassageAppServiceTests`：对称覆盖 finished-product

## 5. 验证

- [x] 5.1 `dotnet test` UrbanManagement.Core.Tests 通过
- [x] 5.2 本地手动：卡口/成品页对失败行重置后 Gov Worker 可再次出队（可选 smoke）— 未跑 UI smoke；Gov Worker 出队条件 `SyncType != 1` 未改，Reset 置 0 后由既有逻辑拾取
