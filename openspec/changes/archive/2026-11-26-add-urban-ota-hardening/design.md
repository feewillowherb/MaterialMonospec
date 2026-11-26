# Design: Urban OTA 打包脚本、看门狗互斥与 30s 启动健康标记

## Decisions

### 1. 一键打包脚本（`scripts/pack-urban-ota.ps1`）

- 必填 `-Version`（SemVer 格式校验），默认 `-OutputDir ".build-verify/urban-releases"`；
- 发布到临时 staging 目录后，显式断言 `Test-Path "$stagingDir/appsettings.json"` 为 `False`，防止误把配置文件打进正式包；
- 调用 `vpk pack --packId MaterialClient.Urban --packVersion $Version --packDir $stagingDir --mainExe MaterialClient.Urban.exe --runtime win-x64 --outputDir $OutputDir`，保留旧版本 nupkg 以自动生成 Delta 差量包。

### 2. 看门狗脚本与 `.updating.lock` 互斥

- `urban-watchdog-tick.ps1`：
  1. 检查 `<InstallRoot>\data\.updating.lock`：若存在且 `(UtcNow - LastWriteTimeUtc).TotalMinutes < LockTimeoutMinutes`（默认 10 分钟），直接退出不拉起；
  2. 检查是否存在同名 `MaterialClient.Urban` 进程：若已运行则退出；
  3. 优先拉起 `<InstallRoot>\current\MaterialClient.Urban.exe`（Velopack 布局），不存在时回退 `<InstallRoot>\MaterialClient.Urban.exe`（绿色布局）。
- `install-urban-watchdog.ps1`：
  - 使用 PowerShell `Register-ScheduledTask`（交互式登录会话 `LogonType Interactive`，避开 Session 0 无法展示 Avalonia GUI 的限制），配置 `AtLogOn` + 每 2 分钟重复触发器。

### 3. 启动 30s 健康标记（`OtaStartupHealthTracker`）

- 纯静态类（遵循 `traits/minimal-di-trait.md`，零新增 DI 服务），读写 `PathManager.DataRoot\.ota-health.json`；
- `RecordStartup(string dataRoot, string version, int maxUnhealthyStarts = 3)`：
  - 版本相同且上次未标记健康 → `ConsecutiveUnhealthyStarts + 1`；
  - 版本变更或上次已标记健康 → 重置为 `1`；
  - `ThresholdExceeded = ConsecutiveUnhealthyStarts >= maxUnhealthyStarts`；
- `MarkHealthy(string dataRoot, string version)`：写入 `IsHealthy = true`、`ConsecutiveUnhealthyStarts = 0`、`LastHealthyAtUtc = DateTime.UtcNow`；
- JSON 解析失败或文件 IO 异常全部 `try/catch` 兜底，绝不阻塞启动。
