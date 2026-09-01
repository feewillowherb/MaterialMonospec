## Context

Urban 本地调试与 pipeline 需要可重复的授权数据。产品内硬编码 `UrbanDebugDevelopmentAuthorization` 无法按项目切换种子，且与 `pipelines/_shared/urban/tools/UpsertLicenseInfo` 方案重复。

## Goals / Non-Goals

**Goals:**

- Pipeline 启动前通过 `Invoke-UrbanLicenseSeed` + `UpsertLicenseInfo` 写入 `license.urban` 与 `LicenseInfo`。
- 支持 `seeds/*.json` 切换项目（`-SeedRelPath`）。
- Debug 构建在演示 JWT machineCode 与本机不一致时仍可启动（仅放宽 machineCode 比对）。
- Release 授权边界不变。

**Non-Goals:**

- 不在产品代码中维护固定演示 `ProjectId` / `AccessCode` 常量。
- 不保证无 seed、畸形 license 时 Debug 仍能启动（该场景由退役的 `urban-debug-license-bypass` 覆盖，已不再需要）。
- 不修改 UrbanManagement 签发规则。

## Decisions

### 1. 授权数据由 pipeline UpsertLicenseInfo 准备

启动脚本 `Start-UrbanForProbe.ps1` 默认调用 `Invoke-UrbanLicenseSeed -Mode Local`。Local 模式在 upsert 前将 seed JSON 的 `machineCode` 补丁为本机，再调用 `UpsertLicenseInfo`。

切换项目：提供不同 `seeds/<project>-license.json`，启动时传 `-SeedRelPath`。

### 2. 移除 UrbanDebugDevelopmentAuthorization

`MaterialClientUrbanModule` Debug/Release 均调用 `TryExecuteStartupLicenseCheckAsync`。删除 `LicenseInfo.CreateDebugDevelopmentAuthorization` 等 Debug 专用实体方法。

### 3. Debug 仅放宽 JWT machineCode 校验

`StaticLicenseChecker` 在 `#if DEBUG` 下记录警告并继续，不因 JWT claim machineCode 与本机不一致而失败。其它 JWT 校验（签名、过期、proId、accessCode）保持严格。

### 4. 保留 Debug 运行时线上授权跳过

`DeviceStatusSignalRClient` 与授权事件处理器在 Debug 下仍 no-op，避免 pipeline 联调时依赖线上 `VerifyJwtAsync` 或收到 Expired/DeviceChanged 后退出。

## Risks / Trade-offs

- [演示 JWT 的 machineCode claim 与 DB 行不一致] → Debug 跳过 claim 比对；DB 行已补丁为本机 machineCode。
- [Release 仍须 machineCode 匹配的 JWT] → 为 Release 准备与本机一致的 seed 或专用 JWT。
- [忘记 seed 导致启动失败] → `Start-UrbanForProbe` 默认 seed；文档明确 `-SkipSeed` 仅用于已灌数场景。

## Migration Plan

1. 移除 `UrbanDebugDevelopmentAuthorization` 与相关测试。
2. 增强 `Invoke-UrbanLicenseSeed`、更新 `Start-UrbanForProbe`。
3. 退役 `urban-debug-license-bypass` Graph。
4. 验证 Debug/Release 构建与授权测试。

## Open Questions

无。
