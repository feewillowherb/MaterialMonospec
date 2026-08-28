# 04 · 能否重写 ABP UoW 以「真正」支持多 DbContext

**日期**：2026-08-28  
**类型**：框架源码对照（非实现）  
**结论先行**：**不必、也不该重写 `IUnitOfWork`。** ABP 已经按连接串把多个 EF Context 收进同一个 UoW；本仓 busy 是 **第二套 Context 没用上已有连接**，掉进了「再 BeginTransaction」分支。

## ABP 已经做了什么

源码：[`UnitOfWorkDbContextProvider.CreateDbContextWithTransactionAsync`](https://github.com/abpframework/abp/blob/dev/framework/src/Volo.Abp.EntityFrameworkCore/Volo/Abp/Uow/EntityFrameworkCore/UnitOfWorkDbContextProvider.cs)

| 键 | 含义 |
|----|------|
| DatabaseApi | `{DbContext 全名}_{连接串 SHA256}` → **每种 Context 各一个实例**（内核 / Urban / Recycle 各一份） |
| TransactionApi | `EntityFrameworkCore_{连接串 SHA256}` → **同一连接串共用一把事务** |

第二个 Context 创建时：

1. 把 `ExistingConnection` 设为 **第一把事务的 `DbConnection`**。  
2. 若新 Context 的 `GetDbConnection() == ExistingConnection` → `UseTransactionAsync`（**共用事务**，这是官方多 Context 同库路径）。  
3. **否则** 注释写明：*User did not re-use the ExistingConnection* → **再 `BeginTransactionAsync`**。

本仓 `MaterialClientEntityFrameworkCoreModule` / `MaterialClientCommonUrbanModule` 一律 `UseSqlite(connectionString, …)`，**从不看 `c.ExistingConnection`**，因此走分支 3。SQLite 文件上第二把写事务 → Error 5。  
这不是「UoW 不支持多 Context」，是 **配置没接上 ABP 已经写好的共享连接**。

官方 Issue 里维护者对「加密连接串 / 指定连接」的写法（SqlServer 同理，Sqlite 把 `UseSqlServer` 换成 `UseSqlite`）：

```csharp
if (c.ExistingConnection != null)
    c.DbContextOptions.UseSqlite(c.ExistingConnection, sqlite => sqlite.MigrationsHistoryTable(...));
else
    c.DbContextOptions.UseSqlite(c.ConnectionString, sqlite => sqlite.MigrationsHistoryTable(...));
```

`AbpDbContextConfigurationContext.ExistingConnection` 是框架公开属性。

文档层：同一 UoW 内多个仓储「一起提交/一起回滚」是 **UoW 编排**；跨 **不同服务器 / 不同连接串** 时 ABP 也承认 **没有真正的跨库数据库事务**（[support#8736](https://abp.io/support/questions/8736)）。本仓三 Context **同一 `Default` 连接串**，属于「同库多 Context」，走 ExistingConnection 才对。

## 用户「重写 UoW」几种含义

| 做法 | 是否优雅 | 说明 |
|------|----------|------|
| 替换 `IUnitOfWork` / `UnitOfWorkManager` | **否** | 与拦截器、事件、仓储全部耦合；要复刻 DatabaseApi/TransactionApi；升级 ABP 即裂 |
| 替换 `IDbContextProvider<T>` / 继承 `UnitOfWorkDbContextProvider` | **几乎不必** | 共享事务逻辑已在基类；定制容易漏 `UseTransaction` / `AttendedDbContexts` |
| **Configure 时 `UseSqlite(ExistingConnection)`**（内核 + Urban + Recycle 三处一致） | **是，框架推荐** | 保留 `[UnitOfWork]`；同一 ambient UoW 内两个 Context 共用连接+事务；不必传 UoW 进 Urban |
| `ReplaceDbContext` 运行时合成单一模型 | **否（相对方案 B）** | ABP 模块文档的「开发多 Context、运行单 Context」会把产品表并回内核模型，与隔离目标冲突 |
| `TransactionScope` / DTC | **SQLite 不适用** | 无跨连接分布式事务；桌面客户端无收益 |

EF Core 官方也要求：多 Context 共用事务必须 **同一 `DbConnection` + `UseTransaction`**（[Share transactions](https://learn.microsoft.com/en-us/ef/core/saving/transactions)）。ABP 的 ExistingConnection 就是为接这条 API。

## 接上 ExistingConnection 之后还要不要串行 UoW？

- **同一方法 ambient UoW、先内核后 Urban**：应能 **一次 Complete**，Urban 写入与内核写入同一 SQLite 事务（若连接复用成功）。这比「禁用 UoW / 传 UoW 参数」更贴 ABP。  
- **仍不要** 在外层 UoW 未结束时对 **另一连接串** 或 **未复用连接** 的 Context `BeginTransaction`。  
- 设计时 Factory（`dotnet ef`）没有 ambient UoW，继续用连接串即可。  
- 后台线程另开 UoW 仍是第二连接；WAL/BusyTimeout 减震，与「同 UoW 多 Context」是两件事。

## 建议

1. 优先做一次 **三模块 UseSqlite 对齐 ExistingConnection**（OpenSpec 小 change），用设置保存 + 称重创建扩展做回归。  
2. **不要** fork ABP UoW。  
3. 在确认共享连接生效前，设置保存的「先 Complete 内核再写 Urban」仍是正确兜底。

反向链接：[03](./03-同库双Context设置保存锁.md)（事故与调用约定）、[02](./02-方案细节.md)（方案 B 同库多 Context）。
