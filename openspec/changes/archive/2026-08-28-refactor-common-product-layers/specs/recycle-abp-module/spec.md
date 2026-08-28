## MODIFIED Requirements

### Requirement: MaterialClientRecycleModule AbpModule 定义
系统 SHALL 定义 `MaterialClientRecycleModule` 类继承 `AbpModule`，依赖 `MaterialClientCommonModule`、内核 EF 模块（提供无 Recycle/Urban 产品实体映射的 `MaterialClientDbContext`）、`MaterialClientCommonRecycleModule`（`MaterialClient.Common.Recycle`）、`MaterialClientUiModule`、`AbpAutofacModule`、`AbpBackgroundWorkersModule`。MUST NOT 依赖 `MaterialClientModule`（主应用模块）或 `MaterialClientUrbanModule` 或 `MaterialClient.Common.Urban`。

#### Scenario: 模块依赖链
- **WHEN** ABP 应用以 `MaterialClientRecycleModule` 初始化
- **THEN** 模块 SHALL 依赖 `MaterialClientCommonModule`（内核实体、枚举、内核 Service API）
- **AND** SHALL 依赖内核 EF 模块（`MaterialClientDbContext`，不含 Recycle 扩展表映射）
- **AND** SHALL 依赖 `MaterialClientCommonRecycleModule`（Recycle 实体、`RecycleDbContext`、Recycle Service API）
- **AND** SHALL 依赖 `MaterialClientUiModule`（提供 Avalonia UI 共享层）
- **AND** SHALL 依赖 `AbpAutofacModule`（提供 Autofac DI 容器）
- **AND** SHALL 依赖 `AbpBackgroundWorkersModule`（提供后台轮询服务支持）
- **AND** MUST NOT 依赖 `MaterialClientModule` 或 `MaterialClientUrbanModule`

### Requirement: Recycle 数据库迁移
`MaterialClientRecycleModule` SHALL 在应用初始化时先执行内核 EF Core 迁移，再执行 Recycle 产品 DbContext 迁移，确保共享实体表与 Recycle 扩展表分别由对应 Context 维护。

#### Scenario: 数据库迁移执行
- **WHEN** `OnApplicationInitializationAsync` 执行
- **THEN** SHALL 先对 `MaterialClientDbContext` 调用 `Database.MigrateAsync()`
- **AND** SHALL 再对 `RecycleDbContext` 调用 `Database.MigrateAsync()`
- **AND** 产品迁移 MUST NOT 由 `MaterialClient.Common` 内的单一混合 DbContext 拥有
