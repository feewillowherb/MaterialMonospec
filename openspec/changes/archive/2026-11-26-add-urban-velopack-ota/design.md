# Design: MaterialClient.Urban Velopack OTA 客户端最小闭环

## Context

`MaterialClient.Urban` 是无人值守工控桌面软件，此前已完成：
1. `appsettings.json` 归零且 `CopyToPublishDirectory="Never"`；
2. `PathManager.DataRoot` 在 Velopack 结构（`<InstallRoot>\current` + `<InstallRoot>\Update.exe`）下自动切换至同盘 `<InstallRoot>\data`。

本设计在 `MaterialClient.Urban` 内落地客户端侧 Velopack OTA 更新引擎，为后续接入 `um-gateway` 静态源和 Admin 灰度控制面做好准备。

## Decisions

### 1. `Program.cs` 入口顺序（NON-NEGOTIABLE）

`VelopackApp.Build().Run()` **必须**放在 `Main(string[] args)` 第一行、单实例 `Mutex` 创建之前：

```csharp
VelopackApp.Build().Run();
Directory.SetCurrentDirectory(AppContext.BaseDirectory);
CodePagesEncodingInitializer.Register();
using var mutex = new Mutex(true, MutexName, out bool createdNew);
```

原因：Velopack 在安装/更新/卸载时会携带 `--veloapp-*` 参数启动目标 `.exe` 执行钩子后立即退出；若放在 `Mutex` 之后，旧进程尚未完全释放 `Mutex` 时会误判为重复实例或阻塞钩子。

### 2. Feed URL 派生与覆写

- `MaterialClientConfigurationDefaults.DefaultOtaUrbanFeedPath = "/updates/urban"`
- `MaterialClientConfigurationDefaults.ResolveOtaFeedUrl(string? explicitFeedUrl, string? urbanManagementBaseUrl)`：
  - 若 `Ota:FeedUrl`（`explicitFeedUrl`）非空白，直接使用（支持 HTTP/HTTPS 静态源或本地文件夹路径，便于 138 实验室与本机验证）；
  - 否则由 `UrbanManagement:BaseUrl`（未配时用 `DefaultUrbanManagementBaseUrl`）拼接 `/updates/urban`。

### 3. 称重空闲门禁与看门狗更新锁

- **称重空闲判定**：通过 `IAttendedWeighingService.GetCurrentStatus() == AttendedWeighingStatus.OffScale` 判定当前无在磅车辆；非 `OffScale` 时 `TryApplyPendingUpdateAsync` 返回 `DeferredNotIdle`，延迟至下个周期重试，绝不在称重中途强行重启。
- **看门狗互斥锁**：触发 `ApplyUpdatesAndRestart` 前在 `PathManager.DataRoot` 写入 `.updating.lock`（含时间戳与目标版本）；应用正常启动完成初始化时自动清理过期 `.updating.lock`。
- **非 Velopack 模式优雅降级**：当 `UpdateManager.IsInstalled` 为 `false`（F5 调试或绿色解压目录运行）时，`CheckAndDownloadUpdateAsync` 直接返回 `NotInstalled` 状态，不抛异常、不发起网络下载。

### 4. 类型与 DI 边界

- 遵循 `traits/minimal-di-trait.md`：
  - `UrbanUpdateService`（`IUrbanUpdateService, ISingletonDependency`）：持有 `UpdateManager` 状态、I/O 与称重状态依赖；
  - `UrbanUpdateBackgroundWorker`（`AsyncPeriodicBackgroundWorkerBase`）：定时触发检查与空闲应用；
  - `OtaOptions`（POCO 选项类，无 DI）；
  - `UrbanUpdateCheckResult`、`UrbanUpdateApplyResult`、`UrbanUpdateStatusSnapshot` 全部使用命名 `record`（遵循 Record 替代 Tuple）。

## Risks / Trade-offs

- **单文件发布（`PublishSingleFile=true`）与 Velopack 兼容**：Velopack 1.x 官方支持 `PublishSingleFile` 或非单文件发布；打包阶段若遇到单文件与 Delta 差量包体积权衡（非单文件 Delta 更小），将在 `vpk pack` 实测中验证并记录最佳参数。
- **本变更不含服务端静态源与 Admin UI**：服务端 `um-gateway` 路由与 Admin 灰度控制面留待下一独立 change；本阶段可通过 `Ota:FeedUrl` 指向本地目录或 138 静态 HTTP 目录完成端到端验证。
