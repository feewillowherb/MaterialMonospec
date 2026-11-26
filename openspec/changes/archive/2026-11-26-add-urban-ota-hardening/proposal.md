# Change: 补齐 MaterialClient.Urban OTA 生产防变砖底座（打包脚本、看门狗互斥与 30s 健康标记）

## Why

`MaterialClient.Urban` 已完成 Velopack OTA 数据面与控制面主干合入，但在无人值守工控机正式投产前还缺少三道工程防线：
1. 缺少标准化一键打包脚本，手工执行 `dotnet publish` 与 `vpk pack` 容易漏掉 `--runtime win-x64`、未校验 `appsettings.json` 残留或误清历史包导致丢失 Delta 差量包；
2. 缺少与 `..\data\.updating.lock` 互斥的 Windows 计划任务看门狗脚本，更新切换瞬间存在看门狗抢跑拉起的风险；
3. 缺少启动后 30 秒健康标记与连续异常启动计数，难以在日志与诊断中识别新版本反复闪退。

## What Changes

- **标准化一键打包脚本（`repos/MaterialClient/scripts/pack-urban-ota.ps1`）**：
  - 封装 `dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -p:Version=<Version>` 与 `vpk pack --runtime win-x64`；
  - 硬校验发布目录中不存在 `appsettings.json`；
  - 复用同一 `-OutputDir` 以便 `vpk` 自动生成 `*-delta.nupkg` 差量包。
- **Windows 计划任务看门狗与更新锁互斥脚本**：
  - 新增 `repos/MaterialClient/scripts/urban-watchdog-tick.ps1`：拉起 `MaterialClient.Urban.exe` 前检查 `<InstallRoot>\data\.updating.lock`（未超过锁超时时间则跳过拉起）及进程是否已在运行，避免与 Velopack 切换目录冲突；
  - 新增 `repos/MaterialClient/scripts/install-urban-watchdog.ps1`：装机一键注册（及 `-Uninstall` 卸载）交互式用户会话的 Windows 计划任务（开机登录 + 每 2 分钟重复）。
- **30 秒启动健康标记（`OtaStartupHealthTracker`）**：
  - 新增静态无 DI 追踪器 `repos/MaterialClient/src/MaterialClient.Urban/Services/Updates/OtaStartupHealthTracker.cs`，在 `PathManager.DataRoot\.ota-health.json` 持久化 `OtaHealthState`（`Version`、`ConsecutiveUnhealthyStarts`、`IsHealthy`、`ThresholdExceeded` 等命名 `record`）；
  - 在 `MaterialClientUrbanModule.OnApplicationInitializationAsync` 记录本次启动并在稳定运行满 30 秒后异步标记健康（清零连续失败计数）；若连续未达健康即重启达到阈值（默认 3 次），记录告警日志。

## Capabilities

### Modified Capabilities
- `urban-velopack-ota`: 新增启动 30s 健康标记、标准化 `vpk` 打包脚本与看门狗 `.updating.lock` 互斥脚本要求。

## Impact

- **受影响仓库**：仅 `repos/MaterialClient`（Mode A：Trunk-direct，分支名 `add-urban-ota-hardening`）。
- **受影响文件**：`scripts/pack-urban-ota.ps1`、`scripts/urban-watchdog-tick.ps1`、`scripts/install-urban-watchdog.ps1`、`src/MaterialClient.Urban/Services/Updates/OtaStartupHealthTracker.cs`、`src/MaterialClient.Urban/MaterialClientUrbanModule.cs`、`tests/MaterialClient.Urban.Tests/Services/OtaStartupHealthTrackerTests.cs`。
- **兼容性**：非破坏性。健康状态文件损坏时自动容错回退，绝不阻塞启动。
