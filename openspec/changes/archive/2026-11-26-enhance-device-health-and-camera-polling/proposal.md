# Proposal: Enhance Device Health Polling, Gate IO Status, and Admin Detail View

## Why

根据调研报告 [02-在线状态与设备监控代码缺陷与不合理设计.md](../../docs/2026-11-26-urban-recycle-logging-online-audit/02-在线状态与设备监控代码缺陷与不合理设计.md)（**O6**）：
- 摄像头仅在启动时探测一次，运行期断网无定时巡检；
- 道闸 IO（`GateIoControlService`）未纳入统一外设在线状态上报；
- 多路摄像头与多路车牌识别（LPR）被压扁为单一布尔值，Admin 无法定位具体哪一路离线，也缺乏异常设备快速筛选视角。

## What Changes

1. **MaterialClient（客户端）**：
   - 新增无 DI 纯逻辑 `DeviceHealthSnapshotFormatter` 与命名 `record`（`DeviceEndpointHealthItem`、`DeviceGroupHealthSummary`），计算聚合状态（`Online` / `Degraded` / `Offline`）并序列化结构化 `AdditionalData` JSON（含 `onlineCount`、`totalCount`、`items`）。
   - `IGateIoControlService` / `GateIoControlService` 暴露只读健康快照 `GetHealthSnapshot()`（命名 `record GateIoHealthSnapshot`）。
   - 在 `MaterialClient.Common` 新增共享 `IDeviceHealthProbeService` / `DeviceHealthProbeService`，定时巡检所有已配置摄像头（`IHikvisionService.IsOnline`）、LPR 设备（`ILprDeviceOnlineStatusService`）与道闸 IO（`GateIoControlService` + 关联 LPR 在线态），通过 `ILocalEventBus` 发布携带结构化 `AdditionalData` 的 `DeviceStatusChangedEventData`。
   - `MaterialClient.Urban` 的 `ClientHeartbeatBackgroundWorker` 按可配置周期（默认 60s）触发健康巡检，使 30s 心跳携带最新外设结构化快照。

2. **UrbanManagement（服务端与 Admin）**：
   - `DeviceStatusService.ValidDeviceTypes` 新增 `"GateIo"`，保持对 1.0 客户端上报格式完全向后兼容。
   - 新增 `DeviceHealthDetailParser` 解析 `AdditionalData` 结构化 JSON（1.0 空值或非 JSON 文本静默降级）。
   - `ProjectManagement.razor` 设备详情弹窗新增 `"GateIo"`（道闸IO）与 `"Degraded"`（部分离线）展示、多路外设明细列表，以及「全部 / 仅看异常」筛选开关。

## Capabilities

### New Capabilities
- `device-health-polling`: 客户端定时外设健康巡检（摄像头、LPR、道闸 IO）、多路结构化明细快照及 Admin 异常筛选展示。

## Impact

- **Repos**: `repos/MaterialClient`, `repos/UrbanManagement`
- **Compatibility**: 新增 `"GateIo"` 与 `"Degraded"` 状态及 `AdditionalData` JSON 均为向前兼容扩展，1.0 客户端与存量数据不受影响。
