# 03 · 同库双 Context：设置保存 SQLITE_BUSY

**现象日期**：2026-08-28（Urban 宿主）  
**类型**：现场事故 + 代码考古（方案 B 落地后的组合写路径）  
**相关日志**：`repos/MaterialClient/.build-verify/Urban/Logs/2026/08/28/MaterialClient.Urban-20260828.log`（约 14:20:04）

## 现象（界面）

设置窗点「确认保存」：**窗口不关、像没反应**。  
真正失败被 catch 后只在窗底显示英文 `Failed to save settings. See logs for details.`（LPR 分区时很容易看不见）。

## 易混淆：同一时段的 502

同日志 14:19 有：

- `DeviceStatusSignalRClient` → `http://191.12.234.212:5233/hubs/devicestatus` **502 Bad Gateway**
- `ServerApprovalSyncCoordinator.PullPendingAsync` → 同一主机 **502**

这是 **远端 UrbanManagement / 网关不可用**，后台重连，**不参与**本地 `Settings` 写入。不要用 502 解释「保存无反应」。

## 真正错误

```text
Failed to save settings
Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 5: 'database is locked'.
  at ... SqliteTransaction..ctor ...
  at MaterialClient.Common.Urban.Services.UrbanSettingsJsonStore.SaveJsonAsync
  at MaterialClient.Common.Services.SettingsService.SaveSettingsAsync
  at MaterialClient.UI.ViewModels.SettingsWindowViewModel.SaveAsync
```

调用栈含义：内核 EF 已在 **同一 `MaterialClient.db` 上持有写事务**，Urban `DbContext` 再 `BeginTransaction` → SQLite **SQLITE_BUSY**（Error 5）。

## 根因（与方案 B 的关系）

方案 B：**一个 SQLite 文件、多个 DbContext**（见 [00](./00-调研总览.md)、[02](./02-方案细节.md)）。  
这是选型时接受的约束，不是「两个库」。

设置拆分后：

| 步骤 | Context | 表 |
|------|---------|-----|
| 内核 `IRepository<SettingsEntity>` | `MaterialClientDbContext` | `Settings`（`UrbanSettingsJson` **Ignore**，不再映射） |
| `IUrbanSettingsJsonStore`（Urban `ReplaceServices`） | `UrbanDbContext` | `UrbanSettingsRows` |

错误实现（事故时）：

1. `SettingsService.SaveSettingsAsync` 带 `[UnitOfWork]` **且** `Begin()` 内核事务。  
2. 在 **同一 ambient / 嵌套 UoW 未 Complete 前** 调用 `UrbanSettingsJsonStore.SaveJsonAsync`（该方法自己再 `[UnitOfWork]`）。  
3. 两个连接、两套事务、**一个文件** → `database is locked`。  
4. `SaveAsync` catch 后不关窗 → 用户感知「无反应」。

读路径同类风险：`GetSettingsAsync` 若在内核 `using` UoW **内部** 调 `GetJsonAsync()`，Urban 读可能碰上内核锁；宜先结束内核 UoW 再读产品表。

## 正确顺序（不变量）

对 **同一 SQLite 文件上的两个 Context**：

1. **不要**在内核事务未提交时开启产品 Context 写事务。  
2. 设置保存：**先** `CompleteAsync` 并 **dispose** 内核 UoW，**再** `IUrbanSettingsJsonStore.SaveJsonAsync`。  
3. **不要**给 `SaveSettingsAsync` 再套一层会包住「产品写」的 `[UnitOfWork]`（拦截器在方法返回前一直占着内核连接）。  
4. Recycle 若将来在同一次用户操作里写内核 + `RecycleDbContext`，同样 **串行提交**，不要并行嵌套。  
5. 禁止跨 Context 共用一个 SQLite 事务来「假装原子」（当前无分布式事务；接受「内核已存、Urban JSON 失败」需日志可见，而不是锁死）。

代码落点：`repos/MaterialClient/src/MaterialClient.Common/Services/SettingsService.cs`（`SaveSettingsAsync` / `GetSettingsAsync`）。  
Urban 实现：`repos/MaterialClient/src/MaterialClient.Common.Urban/Services/UrbanSettingsJsonStore.cs`。

## 界面

失败文案应让用户在「确认保存」旁能看到（中文 + `ex.Message`），避免只写英文且依赖「看日志」。

## 非本事故

- LPR 行级厂商类型、编辑对话框：与 SQLITE_BUSY **无关**。  
- 502：运维 / 网关，另排。
