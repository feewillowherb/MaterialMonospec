## Context

方案 B（同库多 DbContext）已落地。ABP `UnitOfWorkDbContextProvider` 对同一连接串共用 `TransactionApi`，并把 `ExistingConnection` 交给后续 Context。本仓三处 `Configure<AbpDbContextOptions>` 一律 `UseSqlite(connectionString)`，第二套 Context 拿到新连接后走「再 BeginTransaction」分支，SQLite 单写者锁死。调研见 `docs/2026-08-28-materialclient-product-ef-isolation/04-ABP多DbContext与UOW.md`。

桌面宿主无 HTTP 请求级 UoW；`[UnitOfWork]` 仍是方法级 ambient。设置保存曾用「先 Complete 内核再写 Urban」规避 busy，那是症状处理。

## Goals / Non-Goals

**Goals:**

- 同一 ambient UoW、同一 `Default` 连接串下，第二套 DbContext 复用第一把事务的 `DbConnection`，使 ABP 走 `UseTransaction`。
- 三模块配置一致，history 表名不变。
- 保留现有 `DatabaseConnectionStringFactory.FixConnectionString` 的无连接复用路径。

**Non-Goals:**

- 不替换 `IUnitOfWork`、`UnitOfWorkManager`、`IDbContextProvider`。
- 不用 `ReplaceDbContext` 合并模型。
- 不引入 DTC / `TransactionScope`。
- 不改表结构或 migration。
- 不强制删除设置保存的串行 UoW 兜底（回归通过后再决定是否收紧）。
- 不处理「另一线程另开 UoW」的 SQLITE_BUSY（WAL / BusyTimeout 另案）。

## Decisions

1. **只改 SQLite 配置，不 fork UoW**  
   选择：`ExistingConnection != null` 时 `UseSqlite(connection)`，否则 `UseSqlite(已修正连接串)`。  
   备选：自定义 `UnitOfWorkDbContextProvider`。放弃：重复框架逻辑且升级易裂。

2. **三处对齐，可用静态辅助避免漂移**  
   选择：内核 / Urban / Recycle 的 `options.Configure<TContext>` 共用同一套「连接或连接串 + MigrationsHistoryTable」逻辑（静态方法即可，**不注册 DI**）。  
   备选：三处复制 if/else。可接受但易漏 Recycle。

3. **else 分支继续用模块里已 Fix 的连接串，不用擅自换成未修正的 `c.ConnectionString`**  
   选择：与今天行为一致，避免设计时/启动路径绕过 `FixConnectionString`。  
   `ExistingConnection` 路径不需要连接串。

4. **不把 `IUnitOfWork` 传入 Urban Store**  
   共享连接后同一 ambient UoW 内内核仓储与 Urban 仓储即可同事务；传 UoW 不能让两个独立 `UseSqlite(string)` 变成同一 SQLite 事务。

## Risks / Trade-offs

- [辅助方法漏掉某一 Context 的 history 表] → 表名仍由调用方传入 `MaterialClientEfHistory.*`。
- [设计时 Factory 行为变化] → 无 ExistingConnection，仍走连接串；Factory 若手写 UseSqlite 保持原样即可。
- [共享连接后长事务持锁更久] → 与「本来就该同一 UoW」一致；勿把无关后台作业塞进同一 UoW。
- [设置保存仍串行 Complete] → 不冲突；只是可能不再必要。

## Migration Plan

无数据迁移。回滚：三处改回仅 `UseSqlite(connectionString)`。

## Open Questions

无。
