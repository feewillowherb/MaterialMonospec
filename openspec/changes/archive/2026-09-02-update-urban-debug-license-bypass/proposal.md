## Why

MaterialClient.Urban 本地调试与 pipeline 验收需要稳定、可切换项目的授权数据，而不应在产品代码中硬编码固定演示项目上下文。原先引入的 `UrbanDebugDevelopmentAuthorization` 与启动旁路已移除；改为在启动前通过 pipeline 共享工具 `Invoke-UrbanLicenseSeed`（`UpsertLicenseInfo`）写入 `license.urban` 与 SQLite `LicenseInfo`。

## What Changes

- **移除** `UrbanDebugDevelopmentAuthorization` 及 Debug 启动授权旁路；Debug/Release 均走 `TryExecuteStartupLicenseCheckAsync`。
- **保留** Debug 下 `StaticLicenseChecker` 对 JWT **machineCode** 不匹配的放宽（便于共享 `demo-license.json` 跨机调试）；Release 仍严格校验 machineCode。
- **保留** Debug 下 SignalR `VerifyJwtAsync` 跳过与授权过期/设备撤销事件 no-op（避免本地 pipeline 依赖线上授权服务）。
- **增强** `Invoke-UrbanLicenseSeed`：Local 模式 upsert 前将 seed JSON 的 `machineCode` 补丁为本机；支持 `-SeedRelPath` 切换项目种子。
- **更新** `urban-passage-probe` 启动脚本：默认 seed 授权；退役 `urban-debug-license-bypass` Graph。

## Capabilities

### New Capabilities

<!-- None. -->

### Modified Capabilities

- `urban-license-startup-gate`: Debug 与 Release 共用启动 JWT/数据库校验；pipeline 通过 UpsertLicenseInfo 准备授权数据。
- `jwt-anti-tamper-sync`: Debug 仍跳过线上 JWT 核验与过期/撤销恢复；Release 不变。

## Impact

- 受影响仓库：`repos/MaterialClient`、主仓 `pipelines/`。
- 主要代码：`MaterialClientUrbanModule`、`StaticLicenseChecker`（Debug machineCode 放宽）、运行时 Debug 边界（SignalR/事件处理器）。
- Pipeline：`Invoke-UrbanLicenseSeed.ps1`、`Start-UrbanForProbe.ps1`；`urban-debug-license-bypass` 迁入 `_retired/2026-09/`。
