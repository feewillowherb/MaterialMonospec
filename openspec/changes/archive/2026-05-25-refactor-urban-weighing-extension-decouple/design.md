## Context

`UrbanWeighingExtension` 于 2026-05-25 引入，通过 EF `HasOne`/`WithOne` 与 SQLite 外键绑定 `WeighingRecord`。`WeighingRecordService.CreateWeighingRecordAsync` 在同一 UoW 内先后 `InsertAsync` 父/子实体，但父记录 `Id` 在 `autoSave: false` 时仍为 0，导致扩展插入 `WeighingRecordId = 0` 并触发 FK 失败。

项目架构要求 ViewModel 经 Service 访问数据；Urban 扩展与主记录的「关联」属于领域编排，适合集中在 **Domain Service**，而非 ORM 导航或数据库约束。

约束：仍使用单一 `MaterialClientDbContext`；SQLite；ABP `IRepository` + `[UnitOfWork]`；不扩大至 UrbanManagement 服务端。

## Goals / Non-Goals

**Goals:**

- 消除 `UrbanWeighingExtensions` 表对 `WeighingRecords` 的 **数据库外键** 与 EF **导航属性映射**。
- 通过 **`IUrbanWeighingExtensionService`**（Domain Service）创建、查询、更新扩展，并编排与 `WeighingRecord` 的事务边界。
- 修复 Urban 称重记录创建失败（`WeighingRecordId` 在插入扩展前必须为有效 Id）。
- 保留 `WeighingRecordId` 唯一索引与 `(SyncStatus, WeighingRecordId)` 复合索引以支持列表与后台扫描。

**Non-Goals:**

- 合并 `UrbanWeighingExtension` 回 `WeighingRecord` 单表。
- 修改 `WeighingMode` / Urban 启动时 `DefaultWeighingMode` 初始化（可另开 change）。
- UrbanManagement 服务端实体或 API 变更。
- 删除 `WeighingRecords` 上历史遗留的 `SyncStatus` 列。

## Decisions

### 1. 逻辑关联：仅保留 `WeighingRecordId` 列，无 DB FK

**选择**：`UrbanWeighingExtension.WeighingRecordId` 为普通 `long`，迁移中 `DROP` 外键约束；EF 不配置 `HasForeignKey` / `HasOne` / `WithOne`。

**理由**：用户明确要求不在数据库层关联；避免插入顺序与 FK 校验耦合。

**备选**：保留 FK 仅修 `autoSave: true` — 仍保留 DB 层关联，不符合需求。

### 2. 移除 `WeighingRecord.UrbanExtension` 导航属性

**选择**：从实体删除导航属性；查询由 Domain Service 显式 join 或分步加载。

**理由**：无 EF 关系即无 `Include` 依赖，强制调用方走 Service。

### 3. 新增 `IUrbanWeighingExtensionService`（Domain Service）

**职责**：

| 方法（示意） | 说明 |
|-------------|------|
| `CreateForRecordAsync(long weighingRecordId, ...)` | 在父记录已持久化后创建扩展，初始化 Pending |
| `GetByWeighingRecordIdAsync(long id)` | 按 Id 取扩展 |
| `GetPagedWithRecordsAsync(...)` | Urban 列表：按 `WeighingMode == UrbanMode` 查记录并关联扩展（应用层 join 或两次查询） |
| `GetPendingForUploadAsync(...)` | 后台 worker：按 `SyncStatus == Pending` |
| `UpdateSyncStatusAsync(...)` | 上传管线更新状态 |

**标记**：`ITransientDependency` 或 `IDomainService`；写操作 `[UnitOfWork]`。

**`WeighingRecordService` 变更**：Urban 模式创建时调用 `IWeighingRecordRepository.InsertAsync(record, autoSave: true)` 后委托 `IUrbanWeighingExtensionService.CreateForRecordAsync(record.Id)`，不再直接操作 `_urbanWeighingExtensionRepository`。

### 4. 事务边界

**选择**：`CreateForRecordAsync` 由调用方（`WeighingRecordService`）在同一 `[UnitOfWork]` 内先保存父记录再调用 Domain Service；Domain Service 的创建方法亦在 UoW 内 `InsertAsync`。

**理由**：满足「失败则两者回滚」；父 Id 必须先存在（逻辑上，非 FK）。

### 5. 查询实现

**选择**：Domain Service 内使用 `IQueryable`：

- 方案 A：`from r in records join e in extensions on r.Id equals e.WeighingRecordId into ...`（LEFT JOIN 语义）
- 方案 B：先查 `WeighingRecord` 分页，再批量 `Where(e => ids.Contains(e.WeighingRecordId))`

Urban 列表数据量可控，优先 A 保持 Tab 筛选语义。

**不再使用**：`queryable.Include(r => r.UrbanExtension)`。

### 6. 迁移策略

**选择**：新迁移 `RemoveUrbanWeighingExtensionForeignKey`：

1. SQLite：重建表或 `PRAGMA foreign_keys` + 删除 FK（按 EF 生成迁移为准）。
2. 保留 `WeighingRecordId` UNIQUE 与复合索引。
3. 不修改已有行数据。

**回滚**：恢复 FK 需再次迁移；开发环境可接受。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 无 FK 导致孤儿扩展或悬空 `WeighingRecordId` | 仅通过 Domain Service 创建；删除记录时由 Service 显式删除扩展（若存在删除流程） |
| 重复 `WeighingRecordId` | 保留 UNIQUE 索引；创建前 Service 检查是否已存在 |
| 调用方绕过 Service 直接写 Repository | Code review；Urban 路径统一经 `WeighingRecordService` + `IUrbanWeighingExtensionService` |
| 查询性能 | 保留 `(SyncStatus, WeighingRecordId)` 索引；列表仍过滤 `WeighingMode == UrbanMode` |

## Migration Plan

1. 实现 Domain Service 与实体/DbContext 调整。
2. 生成并应用 EF 迁移（删除 FK）。
3. 更新 `WeighingRecordService`、`UrbanAttendedWeighingViewModel` 查询路径。
4. 运行 `UrbanWeighingExtension*` 与称重创建相关测试。
5. 手动验证：Urban 称重稳定后记录 + 扩展均入库，`WeighingRecordId` 非 0。

**回滚**：还原迁移并恢复导航/FK 配置（需代码回退）。

## Open Questions

- `WeighingRecord` 物理删除时是否级联删除扩展？（建议：Domain Service 提供 `DeleteExtensionByRecordIdAsync`，与删除流程挂钩；若无删除流程可延后。）
