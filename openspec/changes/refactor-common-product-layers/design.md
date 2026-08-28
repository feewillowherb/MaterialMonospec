## Context

今日 `MaterialClientDbContext` 位于 `MaterialClient.Common`，同时注册内核表与 `UrbanWeighingExtension`、`RecycleWaybillExtension`。`SettingsEntity.UrbanSettingsJson` 在内核设置表上。标准 / Urban / Recycle 宿主都引用 Common，因此标准端 migration 也会创建产品表。

已采纳调研：方案 B（同 SQLite 双 Context）+ `MaterialClient.Common` 基线 + `MaterialClient.Common.{Product}` 承载产品实体、EF、Service API。宿主 WinExe 只做 UI 与模块组合。OpenSpec 仅在 MaterialMonospec；实现在 `repos/MaterialClient`。

约束：ViewModel 不直接 Repository；多值类型用命名 `record`；UI 不引用 Urban/Recycle 程序集；不处理本 change 未列出的技术债务。

## Goals / Non-Goals

**Goals:**

- 内核表与内核 migration 与产品表解耦
- `Common.Urban` / `Common.Recycle` 成为产品定制层
- 标准宿主不引用产品 Common，新库不建产品表
- Urban 设置离开 `SettingsEntity.UrbanSettingsJson`
- 启动时先内核 migration、再产品 migration

**Non-Goals:**

- 不改 UrbanManagement / BasePlatform
- 不拆分 SQLite 为多文件（方案 D）
- 不使用 ABP `ReplaceDbContext` 合并运行时模型（方案 C）
- 不强制 DROP 旧库残留产品表
- 不把 Avalonia 视图迁入 `Common.*`

## Decisions

### D1: 产品层命名 `MaterialClient.Common.{Product}`

**选择**：产品实体、`{Product}DbContext`、产品 migration、产品 Service 接口与实现放在 `MaterialClient.Common.Urban` / `MaterialClient.Common.Recycle`。

**理由**：调用方需要「产品 Common」而非仅 EF 类库；WinExe 保持瘦。与「Common 基线、Common.* 定制」一致。

**替代**：`MaterialClient.Urban.EntityFrameworkCore` 仅 EF。未采用：Service API 仍会堆在 WinExe 或塞回 Common。

### D2: 内核 EF 独立为 `MaterialClient.Common.EntityFrameworkCore`

**选择**：`MaterialClientDbContext`、内核 Fluent、内核 `Migrations`、设计时 factory、`MaterialClientEntityFrameworkCoreModule` 迁出 Common。

**理由**：Common 去掉 EF 包与产品 `DbSet`；标准宿主只引用 Common + 内核 EF。

**替代**：内核 Context 暂留 Common。允许作为 **第一切片**，但该 Context MUST 删除产品实体映射。完整目标仍是独立内核 EF 项目。

### D3: 禁止 ReplaceDbContext 合并产品模型

**选择**：运行时两个 `AddAbpDbContext`；产品仓储来自产品 Context。

**理由**：合并后产品 DDL 再次进入内核 snapshot，基线无法冻结。

**替代**：方案 A 单 Context 扫产品配置。未采用：标准端仍会迁产品表。

### D4: 同库、分 history 表名

**选择**：同一 `Default` 连接字符串 / `MaterialClient.db`。History：`__EFMigrationsHistory_Kernel`、`__EFMigrationsHistory_Urban`、`__EFMigrationsHistory_Recycle`。SQLite 无可用 schema 隔离。

**替代**：分库文件。未采用：WAL/`ATTACH` 与运维成本。

### D5: 无跨 Context FK；组合在 Service

**选择**：保持逻辑 Id（`WeighingRecordId` / `WaybillId`）。产品 Service 注入内核 `IRepository`/`I*Service` 与产品仓储。需要原子写时共用 `SqliteConnection` + `UseTransaction`，禁止跨线程共享连接。

### D6: UrbanSettingsJson 迁出内核

**选择**：Urban 设置实体映射到 `UrbanDbContext`。内核 `SettingsEntity` 不再要求 `UrbanSettingsJson` 作为基线列（迁移：产品 migration 复制后内核 migration 可删列，或先可空弃用再删）。

**替代**：列留在内核仅 Urban 映射。未采用：违反基线冻结。

### D7: UI 与 mapper

**选择**：`MaterialClient.UI` 只引用 `MaterialClient.Common`。Xiaoshan 等 mapper：**接口**可在 Common，**实现**在 `Common.Urban`，仅 Urban 宿主模块注册。

## Risks / Trade-offs

- [旧库残留表] → 不自动 DROP；文档说明标准端忽略孤儿表
- [双 SaveChanges 非 2PC] → 关键路径共享连接事务；缩短事务，勿夹 HTTP
- [SQLite 单写者] → 两 Context 不增加写并发；WAL + 短事务
- [内核 EF 与产品模块循环引用] → `Common.Urban` 只引用 Common（领域），不引用 WinExe；内核 EF 不引用 `Common.Urban`
- [dotnet ef 多 Context] → 一律 `--context` 与对应 `--project`

## Migration Plan

1. 新增 csproj 与 sln 条目；先搬产品实体与 `UrbanDbContext`（内核 Context 去掉产品 `DbSet`）
2. 产品 baseline migration（已有表 `ExcludeFromMigrations` 或 empty baseline + 对齐现网表名）
3. 内核 history 表重命名或新 history + 记录已应用内核迁移（需一次性脚本，避免重复建表）
4. 宿主 `Migrate`：内核然后产品
5. Urban 设置数据复制后去掉内核列
6. 标准宿主验证：模型不含 Urban/Recycle 实体
7. 回滚：恢复单 Context 需还原程序集引用（高成本）；发布前在分支验证

## Open Questions

- 内核 `__EFMigrationsHistory` 从默认表改名为 `_Kernel` 的现场脚本是否与现有 19 条 migration 一次性完成，还是新库才用新表名、旧库继续默认表直至单独运维 change
- `UrbanSettingsJson` 删列是否与产品设置表同一切片完成（建议同一 change，避免双写窗口过长）
