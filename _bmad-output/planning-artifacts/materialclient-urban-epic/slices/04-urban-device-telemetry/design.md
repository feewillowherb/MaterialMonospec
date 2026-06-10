## Context

需求 6 要求平台侧可见设备与软件健康。与称重上传解耦，独立 API 便于扩展。

## Goals / Non-Goals

**Goals**

- 每台设备有最后心跳时间与客户端版本
- 错误日志可检索、可按设备过滤
- 离线判定：心跳超时 > 2 × 间隔

**Non-Goals**

- 复杂告警规则引擎
- 日志全文检索集群

## Decisions

1. **UrbanDevice**：`DeviceId` (PK string)、`LastHeartbeatAt`、`ClientVersion`、`SoftwareStatus` (Running/Degraded/Stopped)、`LastErrorAt`。
2. **UrbanClientErrorLog**：`DeviceId`、`Level`、`Message`、`Exception`（截断 4KB）、`OccurredAt`。
3. **心跳 DTO**：`DeviceId` 与上传一致，来自 **`IDeviceIdentityProvider`**（首期固定配置 `Guid`）；Version、Status、OptionalMetrics（CPU 等后续）。

4. **未来缓解**：真实设备 ID 与 UrbanManagement 设备主数据对齐时，仅替换 Provider 实现并评估历史心跳数据（另 change）。
5. **客户端**：`UrbanTelemetryBackgroundWorker`（`AsyncPeriodicBackgroundWorkerBase` 或与上传 Worker 同周期策略）注册到 Urban 模块；与 `ILogger` 桥接 — Error+ 自动 enqueue 上报。
6. **客户端 UI**：`WeighingSystemWindow` 底栏 `DeviceStatusList` 绑定 `DeviceStatus` 集合（圆点颜色 + 设备名 + 状态文案）。
7. **服务端 UI**：`Views/Device/Index.cshtml` LayUI 表格，或仅 API 首期。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 日志洪水 | 客户端采样/合并；服务端速率限制 |
| 时钟漂移 | 使用 UTC；服务端记录 ReceivedAt |
| 固定 `DeviceId` 多客户端合并 | 与 slice 03 相同；**未来缓解**见 ADR-9 |
