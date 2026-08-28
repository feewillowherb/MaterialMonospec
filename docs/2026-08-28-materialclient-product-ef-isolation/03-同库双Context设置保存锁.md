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

---

## ABP 里这个问题本质是什么

ABP 的 `IUnitOfWork` 是 **ambient 作用域**：外层 `Begin()` / `[UnitOfWork]` 未 `Complete`+`Dispose` 前，内层再标 `[UnitOfWork]` **默认加入同一 UoW**，不会 magically 变成「第二个 SQLite 事务已经安全」。

同一 UoW 里解析 **两个** `DbContext`（`MaterialClientDbContext` 与 `UrbanDbContext` / `RecycleDbContext`）时，EF 会各开一条连接到 **同一个** `MaterialClient.db`。SQLite 默认 journal 下 **两个写事务不能并存** → Error 5 `database is locked`。

因此：

- **不是**「ABP 不会用、要手写 ADO」。  
- **也不是**「给每个仓储都加 `[UnitOfWork]` 就隔离了」——内层属性在有 ambient UoW 时往往 **加深嵌套**，而不是切开连接。  
- ABP **没有** 跨两个 EF SQLite Context 的分布式事务（不同连接串时）。**同一连接串** 时框架已按连接串哈希共用 `TransactionApi`，第二套 Context 应 `UseTransaction`；本仓因 `UseSqlite(连接串)` 忽略 `ExistingConnection` 才再开第二把事务。详见 [04-ABP多DbContext与UOW.md](./04-ABP多DbContext与UOW.md)。

`[UnitOfWork]` 本身没有错：内核-only 或产品-only 的方法就该标。危险的是 **一个 ambient UoW 里既碰内核仓储又碰产品仓储**。

## 客户端没有 HTTP scope，是否还该用 UoW？

**该用。** 本仓是 Avalonia 桌面进程，没有 ASP.NET 的 per-request UoW。ABP 在这里的作用域是 **一次带 `[UnitOfWork]` 的方法调用**（拦截器 `Begin` → 方法结束 `Complete`），不是「整个窗口 / 整个进程一条事务」。这和 Web 的「一请求一 UoW」同构，只是触发点换成 Service 方法而不是中间件。

因此 **不要**为了躲 SQLITE_BUSY 就全局关掉 UoW：维护成本会升（谁忘了 `SaveChanges`、异常要不要回滚全靠手写），也和现有 DomainService 习惯冲突。桌面侧真正要避免的是：把 UoW 拖得很长（跨 UI 等待、跨 SignalR），或在 **同一次方法作用域** 里打开第二套 DbContext 写锁。

## 把内核 UoW「传给」Urban Service 会不会大规模 busy？

**会锁的条件不变：同一 ambient UoW 里出现第二套 SQLite 写连接。** 把 `IUnitOfWork` 当参数传进 Urban 专用 Service **不会**让两个 Context 共用一把 SQLite 事务。

ABP 一个 `IUnitOfWork` 可以挂多个 `DbContext`，但 EF/SQLite 仍是 **每 Context 一条连接、各 BeginTransaction**。Urban 仓储一旦解析 `UrbanDbContext`，文件上就有第二把写锁，和「传没传 UoW 对象」无关——ambient 已经在了，传参只是把同一把锁显式化，**busy 概率不降**。

规模上：

- **不会**「所有标了 `[UnitOfWork]` 的内核方法」都 busy。只碰 `Settings` / `WeighingRecord` / `Waybill` 的调用仍然是单 Context。  
- **会**在「内核方法还没返回、内部再调 Urban/Recycle 写」这条边上 busy。这类边是 **有限的编排点**（设置保存、称重落库后写扩展、Recycle 收货），不是全仓每一个 Service。  
- 桌面比 HTTP 更容易放大的是：**单例 Service 里 `Begin()` 跨异步回调迟迟不 Dispose**，与后台任务抢同一文件。那是生命周期问题，不是「该不该用 UoW」。

结论：Urban 专用 Service **继续** `[UnitOfWork]`，但只由 **没有内核 ambient UoW** 的调用方进入（内核方法先返回 / `OnCompleted` 后再调）。不要为了「传递 UoW」把 Urban 写嵌进内核事务。

## 在 ABP 中的优雅做法（推荐顺序）

### 1. 约定：一个 UoW = 一个 Context 族（首选，且保留 `[UnitOfWork]`）

| 层 | 做法 |
|----|------|
| 内核 DomainService | 继续 `[UnitOfWork]`，方法内 **只** 内核仓储 |
| Urban / Recycle 专用 Service | 继续 `[UnitOfWork]`，方法内 **只** 产品 Context |
| 必须先内核后产品的编排 | 两个 **先后** 的带 UoW 的方法：内核方法结束（拦截器 Complete）→ 再调 Urban 方法（新的方法级 UoW）。薄编排层可以不标 UoW，但 **两边业务方法都保留属性** |

不要把「编排层不标 UoW」理解成项目弃用 UoW。

编排伪代码（与当前 `SettingsService.SaveSettingsAsync` 同构）：

```csharp
using (var uow = _uowManager.Begin())
{
    // 只内核
    await uow.CompleteAsync();
}

using (var uow = _uowManager.Begin(requiresNew: true))
{
    // 只产品 Context
    await uow.CompleteAsync();
}
```

`requiresNew: true` **只有在外层已经 Dispose** 时才安全。外层还活着就 `requiresNew`，等于第二把写锁去抢同一文件，仍然 BUSY。

### 2. 更「ABP 味」：`IUnitOfWork.OnCompleted`

内核提交成功后再开产品 UoW，避免调用方漏写顺序：

```csharp
using var uow = _uowManager.Begin();
await _settingsRepository.UpdateAsync(...);
uow.OnCompleted(async () =>
{
    using var product = _uowManager.Begin(requiresNew: true);
    await _urbanSettingsJsonStore.SaveJsonAsync(json);
    await product.CompleteAsync();
});
await uow.CompleteAsync();
```

适合「内核必须先成功，产品失败单独打日志/重试」。不要用它假装跨库原子。

### 3. 产品副作用放到 UoW **之后**（钩子）

`IUrbanWeighingRecordSideEffects.AfterWeighingRecordCreatedAsync` 应在 **内核 `CompleteAsync` 之后** 调用，而不是插在 `using var uow` 中间。  
今日 `WeighingRecordService.CreateWeighingRecordAsync` 仍是：内核 `Begin` → `Insert` → **UoW 未结束** → `AfterWeighingRecordCreatedAsync` → `CreateForRecordAsync`（Urban `[UnitOfWork]` + `autoSave`）。这与设置保存是 **同一类缺陷**，Urban 称重创建扩展时可能再锁。

### 4. 仅作减震、不能当架构：WAL + Busy Timeout

连接串增加 `Cache=Shared`，启动时 `PRAGMA journal_mode=WAL;`，Busy Timeout 数秒。  
能缓解 **读/写交错、后台任务与 UI**，**不能**让两个 `BEGIN IMMEDIATE` 写事务同时成功。不要靠它代替串行 UoW。

### 5. 不要做的

- 两个 Context 共用一个 `SqliteConnection` 硬绑成「一个事务」（生命周期和 ABP 连接管理打架）。  
- `ReplaceDbContext` 把产品模型并回内核（等于撤销方案 B）。  
- 拆成两个 `.db` 文件（非目标，见 [02](./02-方案细节.md)）。  
- 给 ViewModel 套 `[UnitOfWork]`。  
- 把 `IUnitOfWork` 从内核传到 Urban，指望共用 SQLite 事务。  
- 认为「代码里 `[UnitOfWork]` 很多 = 到处会 lock」——见下一节。  
- 为躲 busy 全局 `IsDisabled` 掉 UoW。

## 「会不会有大量 database is locked」

**不会**是每一个 `[UnitOfWork]` 都会锁。仓库里大量属性只打在 **单一 Context** 的 Service 上（`MaterialService`、`ProviderService`、`AttachmentService` 等），SQLite 单连接写是正常的。

**会**锁的是 **跨 Context 组合写（或长事务里第二套写连接）**。当前高风险清单（审计，不是「已全部复现」）：

| 路径 | 为何像设置事故 |
|------|----------------|
| `SettingsService` + `UrbanSettingsJsonStore` | **已踩实**；现已串行。Get 也已先结束内核 UoW 再读 Urban。 |
| `WeighingRecordService.CreateWeighingRecordAsync` 在内核 UoW 内调 `AfterWeighingRecordCreatedAsync` | Urban `CreateForRecordAsync` 在 ambient 内核事务上再写 `UrbanWeighingExtensions` |
| `UrbanWeighingExtensionService.CreateForRecordAsync(evaluateAnomaly: true)` | **同一方法**里 `_weighingRecordRepository.GetAsync`（内核）+ `_extensionRepository.InsertAsync`（Urban） |
| `RecycleReceivingService.ConfirmAsync` `[UnitOfWork]` 内 `Waybill` 更新 + `IRecycleWaybillExtensionStore.UpsertReceivingTimeAsync`（Store 自己还有 `[UnitOfWork]`） | 内核 + Recycle 同 ambient |
| `RecycleWeighingService.UpdateRecycleModeAsync` | 称重/运单内核仓储 + Recycle Store，同一 `[UnitOfWork]` |
| `WeighingMatchingService` 匹配成功后写 `IRecycleWaybillExtensionStore` | 若外层仍占内核 UoW，同类 |

后台 502 / SignalR 重连 **另占用连接**，WAL 下多为读或短写，一般不是设置保存的主因，但会放大 Busy。

清扫策略（若单开 change）：只改 **编排边界**（先 Complete 内核再调产品钩子；产品 Service 禁止混注入内核仓储），**不要**批量删除所有 `[UnitOfWork]`。

