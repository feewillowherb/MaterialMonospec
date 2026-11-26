# Tasks: update-materialclient-velopack-data-root

> 目标仓库：`repos/MaterialClient`（Mode A：Trunk-direct，Apply 前切到同名分支 `update-materialclient-velopack-data-root`）。

## 1. Velopack 感知数据根目录解析（`MaterialClient.Common`）

- [x] 1.1 在 `PathManager.cs` 新增 `ResolveDefaultDataRoot(string? executableDirectory = null)`，在 `current\` + 上级 `Update.exe` 存在时自动创建并返回 `..\data`，否则返回可执行目录；更新 `_appBaseDirectory` 初始化与 `ResetDataRoot()` 使用该方法。
- [x] 1.2 更新 `MaterialClientConfigurationDefaults.ResolveExeDirectoryConnectionString()` 默认基目录改用 `PathManager.DataRoot`。

## 2. 全仓运行期数据路径统一收口

- [x] 2.1 更新 `SerilogFileLogConfigurator.cs` 与 `MaterialClient.Urban/Services/ClientLogPullService.cs`，将相对 `Log:Directory` 基目录改为 `PathManager.DataRoot`。
- [x] 2.2 更新 `LocalImageCleanupService.cs`、`HikvisionService.cs`、`TicketPrintingService.cs`，将运行期清理/抓拍/磅单输出相对路径基目录改为 `PathManager.DataRoot`。
- [x] 2.3 更新 `MaterialClientModule.cs`、`MaterialClientUrbanModule.cs`、`MaterialClientRecycleModule.cs`：当 `PathManager.DataRoot` 与 `AppContext.BaseDirectory` 不同时，追加加载 `PathManager.DataRoot` 下的可选 `appsettings.json` 与 `appsettings.secret.json`。

## 3. 单元测试与构建验证

- [x] 3.1 补充单元测试验证：`PathManager.ResolveDefaultDataRoot` 在 Velopack 结构下自动创建并返回 `..\data`、非 Velopack 结构下返回可执行目录，以及 `ResolveExeDirectoryConnectionString` 跟随 `PathManager.DataRoot`。
- [x] 3.2 执行 `dotnet build MaterialClient.sln -o .build-verify` 与 `dotnet test`，确保全量编译与单测通过。
