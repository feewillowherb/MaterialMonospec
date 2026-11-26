# Tasks: add-urban-ota-hardening

> 目标仓库：`repos/MaterialClient`（Mode A：Trunk-direct，Apply 前切到同名分支 `add-urban-ota-hardening`）。

## 1. 打包与看门狗脚本

- [x] 1.1 新增 `repos/MaterialClient/scripts/pack-urban-ota.ps1`：封装 Release `win-x64` 发布、断言无 `appsettings.json` 及 `vpk pack --runtime win-x64`（支持复用输出目录自动生成 Delta 差量包）。
- [x] 1.2 新增 `repos/MaterialClient/scripts/urban-watchdog-tick.ps1` 与 `repos/MaterialClient/scripts/install-urban-watchdog.ps1`：实现 `.updating.lock` 互斥检查与交互式计划任务注册/卸载。

## 2. 30 秒启动健康标记

- [x] 2.1 新增 `repos/MaterialClient/src/MaterialClient.Urban/Services/Updates/OtaStartupHealthTracker.cs`（命名 `record OtaHealthState` + 静态读写与容错逻辑）。
- [x] 2.2 更新 `repos/MaterialClient/src/MaterialClient.Urban/MaterialClientUrbanModule.cs`：启动时调用 `OtaStartupHealthTracker.RecordStartup`，并调度 30 秒后异步调用 `MarkHealthy`。

## 3. 验证与测试

- [x] 3.1 新增 `repos/MaterialClient/tests/MaterialClient.Urban.Tests/Services/OtaStartupHealthTrackerTests.cs` 覆盖正常健康标记、连续 3 次异常触发 `ThresholdExceeded`、版本切换重置计数与损坏 JSON 容错。
- [x] 3.2 验证 3 个 PowerShell 脚本语法解析无误、验证 `urban-watchdog-tick.ps1` 在存在 `.updating.lock` 时安全跳过，并执行 `dotnet build` 与 `dotnet test`。
