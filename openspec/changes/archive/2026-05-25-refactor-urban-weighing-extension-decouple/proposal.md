## Why

当前 `UrbanWeighingExtension` 与 `WeighingRecord` 通过 EF Core 导航属性与数据库外键（`FK_UrbanWeighingExtensions_WeighingRecords`）绑定。Urban 创建记录时因在 `InsertAsync` 后父实体 `Id` 尚未生成，扩展行以 `WeighingRecordId = 0` 写入，触发 SQLite **FOREIGN KEY constraint failed**，称重记录创建失败。将关联从数据库层上移到 **Domain Service** 管理，可消除 FK/导航带来的插入顺序问题，并保持 Urban 扩展数据与主记录在应用层显式、可测试地协作。

## What Changes

- **移除数据库层关联**：删除 `UrbanWeighingExtension` ↔ `WeighingRecord` 的 EF 外键、`HasOne`/`WithOne` 导航配置；`WeighingRecord` 不再暴露 `UrbanExtension` 导航属性（或标记为不映射）。
- **保留逻辑关联字段**：`UrbanWeighingExtension.WeighingRecordId` 保留为普通 `long` 列（无 FK 约束），由应用保证语义一致；保留 `WeighingRecordId` 唯一索引与查询用复合索引。
- **引入 Domain Service**：新增（或扩展）`IUrbanWeighingExtensionService` / `UrbanWeighingExtensionService`，负责 Urban 模式下扩展行的创建、按 `WeighingRecordId` 查询/更新、与列表/后台同步所需的组合查询；**禁止**在 `WeighingRecordService` 内直接编排双表插入顺序。
- **修正创建生命周期**：先 `autoSave`（或等价）持久化 `WeighingRecord` 取得真实 `Id`，再由 Domain Service 插入扩展；同一 `UnitOfWork` 内保证事务一致性。
- **查询路径调整**：Urban 列表、Tab 筛选、后台 Pending 扫描改经 Domain Service（或专用查询方法）关联两表，不再依赖 EF `Include(UrbanExtension)`。
- **迁移**：新增 EF 迁移删除 FK 约束；现有数据保留，`WeighingRecordId` 列不变。
- **BREAKING**（实现层）：依赖 `WeighingRecord.UrbanExtension` 导航或 EF 自动级联的代码须改为经 Domain Service 访问。

## Capabilities

### New Capabilities

（无 — 行为在既有 Urban 扩展能力上重构。）

### Modified Capabilities

- `urban-weighing-extension`：关联模型从「EF/DB 外键 + 导航」改为「逻辑 `WeighingRecordId` + Domain Service 编排」；创建、查询、事务与索引要求相应更新。

## Impact

| 范围 | 说明 |
|------|------|
| **MaterialClient** | `MaterialClient.Common`：实体、`MaterialClientDbContext` Fluent API、迁移、`WeighingRecordService`；新增 `UrbanWeighingExtensionService`；`MaterialClient.Urban` ViewModel/查询调用路径 |
| **测试** | `UrbanWeighingExtensionTests`、查询/创建相关单元测试需对齐无 FK 与 Domain Service 模式 |
| **数据** | 需迁移删除 FK；历史 `UrbanWeighingExtensions` 行无需重建 |
| **OpenSpec** | 归档后合并 `urban-weighing-extension` 主 spec delta |
