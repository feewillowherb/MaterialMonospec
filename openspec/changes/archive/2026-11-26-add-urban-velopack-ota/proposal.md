# Change: 在 MaterialClient.Urban 接入 Velopack OTA 更新引擎与称重空闲门禁

## Why

完成 `appsettings` 清理与 `PathManager.DataRoot`（Velopack 同盘 `..\data\`）外置隔离后，`MaterialClient.Urban` 已具备无人值守远程更新（OTA）的前置条件。下一步需要在 `MaterialClient.Urban` 试点落地客户端侧 Velopack OTA 最小闭环：
1. 在程序入口正确接管 Velopack 安装/更新/卸载生命周期钩子，且不与现有单实例 `Mutex` 冲突；
2. 支持从统一静态源（默认 `{UrbanManagement:BaseUrl}/updates/urban`，可由 `Ota:FeedUrl` 覆写）后台静默检查与下载更新包；
3. 在执行切换重启前通过**称重空闲门禁**（地磅状态为 `OffScale`）与更新锁标记（`.updating.lock`），防止在称重中途强杀或与看门狗抢跑；
4. 在未通过 Velopack 安装的本地调试 / 绿色解压模式下优雅降级为 no-op，零影响既有开发与运行体验。

## What Changes

- **引入 `Velopack`（`1.2.161`）**：在 `Directory.Packages.props` 与 `MaterialClient.Urban.csproj` 添加 `Velopack` 依赖。
- **入口钩子与单实例协调**：在 `MaterialClient.Urban/Program.cs` 的 `Main` 最顶部（创建单实例 `Mutex` 之前）调用 `VelopackApp.Build().Run()`，确保 Velopack 生命周期子命令不会与单实例锁冲突。
- **配置默认值与选项**：
  - 在 `MaterialClientConfigurationDefaults` 新增 `DefaultOtaUrbanFeedPath = "/updates/urban"` 与 `ResolveOtaFeedUrl(string? explicitFeedUrl, string? urbanManagementBaseUrl)`；
  - 新增 `OtaOptions`（绑定 `Ota` 节：`Enabled` 默认 `true`、`FeedUrl` 可选覆写、`CheckIntervalMinutes` 默认 `30`、`AutoApplyWhenIdle` 默认 `true`）。
- **核心 OTA 服务与后台定时检查**：
  - 新增 `IUrbanUpdateService` / `UrbanUpdateService`（`ISingletonDependency`）：封装 `UpdateManager` 检查/下载、称重空闲门禁（校验 `IAttendedWeighingService.GetCurrentStatus() == AttendedWeighingStatus.OffScale`）、`.updating.lock` 锁文件与状态快照 `UrbanUpdateStatusSnapshot`（命名 `record`）；
  - 新增 `UrbanUpdateBackgroundWorker`（`AsyncPeriodicBackgroundWorkerBase`）：按配置周期静默检查并下载更新，仅在门禁允许且开启自动应用时触发切换重启；
  - 在 `MaterialClientUrbanModule` 注册 `OtaOptions` 并在 `Ota:Enabled=true` 时注册后台 Worker。
- **打包验证**：新增可复用的本地 `vpk` 打包验证（生成 `releases.win.json`、`*-full.nupkg` 与 `*-delta.nupkg`，并验证发布目录不含 `appsettings.json`）。

## Capabilities

### New Capabilities
- `urban-velopack-ota`: 定义 `MaterialClient.Urban` 客户端侧 Velopack OTA 入口钩子、Feed URL 自动派生与覆写、非安装模式优雅降级、称重空闲门禁与静默后台更新契约。

### Modified Capabilities
- 无现有 spec 修改。

## Impact

- **受影响仓库**：仅 `repos/MaterialClient`（Mode A：Trunk-direct，分支名 `add-urban-velopack-ota`）。
- **受影响项目**：`Directory.Packages.props`、`MaterialClient.Common`、`MaterialClient.Urban`、`MaterialClient.Urban.Tests`、`MaterialClient.Common.Tests`。
- **兼容性**：非破坏性。非 Velopack 模式下自动识别 `IsInstalled == false` 并安全跳过更新操作，不报错、不阻塞启动。
- **后续衔接**：服务端 `um-gateway` 静态包托管与 Admin 2.0 灰度控制面将在后续跨仓 change 中接入，本变更不改动 `UrbanManagement`。
