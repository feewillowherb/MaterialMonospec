# Tasks: add-urban-velopack-ota

> 目标仓库：`repos/MaterialClient`（Mode A：Trunk-direct，Apply 前切到同名分支 `add-urban-velopack-ota`）。

## 1. 依赖与配置默认值

- [x] 1.1 在 `Directory.Packages.props` 添加 `Velopack` `1.2.161`，并在 `MaterialClient.Urban.csproj` 添加 `<PackageReference Include="Velopack" />`。
- [x] 1.2 在 `MaterialClientConfigurationDefaults.cs` 新增 `DefaultOtaUrbanFeedPath = "/updates/urban"` 与 `ResolveOtaFeedUrl(string? explicitFeedUrl, string? urbanManagementBaseUrl)`。
- [x] 1.3 在 `MaterialClient.Urban/Configuration/OtaOptions.cs` 新增 `OtaOptions` 配置模型（`Enabled = true`, `FeedUrl`, `CheckIntervalMinutes = 30`, `AutoApplyWhenIdle = true`）。

## 2. 入口钩子、OTA 服务与后台定时检查

- [x] 2.1 更新 `MaterialClient.Urban/Program.cs`：在 `Main` 第一行（单实例 `Mutex` 之前）调用 `VelopackApp.Build().Run()`。
- [x] 2.2 新增 `MaterialClient.Urban/Services/Updates/UrbanUpdateService.cs`（包含 `IUrbanUpdateService`、命名 `record` 结果模型、`UrbanUpdateService`）：封装 Velopack `UpdateManager` 检查/下载、非安装态优雅降级、`AttendedWeighingStatus.OffScale` 空闲门禁、`.updating.lock` 写入与启动清理。
- [x] 2.3 新增 `MaterialClient.Urban/Backgrounds/UrbanUpdateBackgroundWorker.cs`（`AsyncPeriodicBackgroundWorkerBase`），并在 `MaterialClientUrbanModule.cs` 中绑定 `OtaOptions`、清理残留 `.updating.lock` 及按 `Ota:Enabled` 注册后台 Worker。

## 3. 单元测试、编译与 `vpk` 打包验证

- [x] 3.1 在 `MaterialClient.Common.Tests` 与 `MaterialClient.Urban.Tests` 补充单元测试：覆盖 `ResolveOtaFeedUrl` 派生与覆写、非 Velopack 模式优雅降级、称重非空闲拦截更新与空闲放行写入 `.updating.lock`。
- [x] 3.2 执行 `dotnet build MaterialClient.sln -o .build-verify` 与 `dotnet test`，确保全量编译与单测通过。
- [x] 3.3 本地安装/调用 `vpk` 对 `MaterialClient.Urban` 执行 `dotnet publish` + `vpk pack` 实测，验证产物包含 `releases.win.json` / `*-full.nupkg` 且发布目录不含 `appsettings.json`。
