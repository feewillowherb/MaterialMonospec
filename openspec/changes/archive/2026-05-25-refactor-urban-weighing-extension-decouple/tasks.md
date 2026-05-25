## 1. 实体与 EF 配置（MaterialClient.Common）

- [x] 1.1 从 `WeighingRecord` 移除 `UrbanExtension` 导航属性；从 `UrbanWeighingExtension` 移除 `WeighingRecord` 导航属性
- [x] 1.2 更新 `MaterialClientDbContext.OnModelCreating`：删除 `HasOne`/`WithOne`/`HasForeignKey`；保留 `WeighingRecordId` 唯一索引与 `(SyncStatus, WeighingRecordId)` 复合索引
- [x] 1.3 新增 EF 迁移 `RemoveUrbanWeighingExtensionForeignKey`（删除 FK，保留列与索引），本地验证迁移可应用

## 2. Domain Service

- [x] 2.1 新增 `IUrbanWeighingExtensionService` / `UrbanWeighingExtensionService`（`MaterialClient.Common/Services/Urban/`）：`CreateForRecordAsync`、`GetByWeighingRecordIdAsync`、`GetPagedWithRecordsAsync`、`GetPendingForUploadAsync`、`UpdateSyncStatusAsync`（按 design 最小集实现）
- [x] 2.2 写操作加 `[UnitOfWork]`；创建前检查 `weighingRecordId > 0` 且唯一索引不冲突
- [x] 2.3 在 ABP 模块中注册服务（`ITransientDependency` 或 DomainService 惯例）

## 3. 称重记录创建路径

- [x] 3.1 重构 `WeighingRecordService.CreateWeighingRecordAsync`：`InsertAsync(weighingRecord, autoSave: true)` 取得真实 `Id` 后，Urban 模式调用 `IUrbanWeighingExtensionService.CreateForRecordAsync`
- [x] 3.2 移除 `WeighingRecordService` 对 `IRepository<UrbanWeighingExtension>` 的直接依赖（改注入 Domain Service）
- [x] 3.3 手动验证：Urban 称重稳定后 `WeighingRecords` 与 `UrbanWeighingExtensions` 均入库且 `WeighingRecordId` 非 0

## 4. 查询与 Urban UI

- [x] 4.1 将 `GetPagedUrbanWeighingRecordsAsync` 迁至 `IUrbanWeighingExtensionService`（或委托实现），使用 join/关联查询替代 `Include(r => r.UrbanExtension)`
- [x] 4.2 更新 `UrbanAttendedWeighingViewModel` 调用路径（若方法签名变更）
- [x] 4.3 若有后台上传 worker 扫描 Pending，改为经 Domain Service 查询

## 5. 测试与验证

- [x] 5.1 更新 `UrbanWeighingExtensionTests` / `UrbanWeighingExtensionQueryTests`：对齐无导航、无 FK 假设
- [x] 5.2 新增或更新创建流程测试：模拟父记录 Id 生成后扩展创建，断言无 `WeighingRecordId = 0`
- [x] 5.3 运行 `MaterialClient.Common.Tests` 相关套件并通过
