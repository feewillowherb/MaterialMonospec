## 1. Shared SQLite options helper

- [x] 1.1 在内核 EF 程序集增加静态辅助（不注册 DI）：当 `ExistingConnection` 非空时 `UseSqlite(connection, historyTable)`，否则 `UseSqlite(已 Fix 的连接串, historyTable)`，并保留 DetailedErrors / SensitiveDataLogging 与现网一致
- [x] 1.2 辅助方法入参包含 history 表名，调用方传入 `MaterialClientEfHistory` 对应常量

## 2. Wire all three modules

- [x] 2.1 `MaterialClientEntityFrameworkCoreModule` 的 `MaterialClientDbContext` 配置改走辅助方法
- [x] 2.2 `MaterialClientCommonUrbanModule` 的 `UrbanDbContext` 配置改走辅助方法
- [x] 2.3 `MaterialClientCommonRecycleModule` 的 `RecycleDbContext` 配置改走辅助方法
- [x] 2.4 确认三处均未替换 `IUnitOfWork` / `IDbContextProvider`，且未使用 `ReplaceDbContext`

## 3. Verify

- [x] 3.1 编译 MaterialClient（含 Urban / Recycle 宿主项目）
- [ ] 3.2 手工：Urban 设置保存（内核设置 + Urban JSON 同一保存路径）不再出现 SQLite Error 5；失败时仍有中文提示
- [ ] 3.3 手工（若环境允许）：称重创建后写 Urban 扩展或 Recycle 收货等同 UoW 跨 Context 路径无 database is locked
