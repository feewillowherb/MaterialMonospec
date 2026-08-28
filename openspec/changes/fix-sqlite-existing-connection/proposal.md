## Why

内核与 Urban / Recycle 共用同一 SQLite 文件、同一 `Default` 连接串，但各自 `UseSqlite(连接串)` 会打开**新连接**。ABP 在同一 ambient UoW 里对第二套 DbContext 会再 `BeginTransaction`，SQLite 报 Error 5（database is locked），设置保存与同 UoW 跨 Context 写入失败。不必重写 `IUnitOfWork`：框架已按连接串共享事务，缺的是复用 `ExistingConnection`。

## What Changes

- 内核、Urban、Recycle 的 `AbpDbContextOptions` 配置：若 `AbpDbContextConfigurationContext.ExistingConnection` 非空，则 `UseSqlite(ExistingConnection, …)`；否则仍用现有修正后的连接串。
- 各 Context 的独立 migration history 表名保持不变。
- **禁止**替换或 fork `IUnitOfWork` / `UnitOfWorkManager` / `IDbContextProvider`。
- **禁止**用 `ReplaceDbContext` 把产品模型并回内核。
- 不把「先 Complete 内核再写 Urban JSON」的设置保存兜底当作必须删除项；共享连接生效后同一 UoW 应可一次 Complete，兜底可保留直至回归确认。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `product-dbcontext-isolation`: 同库多 DbContext 在同一 ABP UnitOfWork 内 MUST 复用已有 SQLite 连接并 `UseTransaction`，不得为第二套 Context 再开独立写事务。

## Impact

- 仅 **MaterialClient**：`MaterialClientEntityFrameworkCoreModule`、`MaterialClientCommonUrbanModule`、`MaterialClientCommonRecycleModule`（及可选的静态配置辅助，避免三处漂移）。
- 设计时 Factory 无 ambient UoW，继续走连接串分支。
- UrbanManagement / FdSoft.BasePlatform 无变更。不改表结构、不改 migration。
