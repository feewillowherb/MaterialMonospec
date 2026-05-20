## Why

UrbanManagement 需掌握所有采集端的**设备状态、软件运行状态与错误日志**，满足运维与监管（需求 6）。

## What Changes

**MaterialClient.Urban**

- **`IUrbanTelemetryService`**：定时心跳（版本、运行状态、最后称重时间）。
- 统一 **错误日志上报**：捕获未处理异常、上传失败、授权文件缺失等，POST 至服务端。
- 配置 `HeartbeatIntervalSeconds`。
- 主界面 **底栏 `DeviceStatusList`**（见 `WeighingSystemWindow.axaml` Row3）展示本地设备状态，与上报数据一致。

**UrbanManagement**

- 实体 **`UrbanDevice`**（设备注册/最后心跳）、**`UrbanClientErrorLog`**。
- API：`POST /api/urban/devices/heartbeat`、`POST /api/urban/devices/logs`。
- 管理端：设备列表（在线/离线推断）、按设备查看错误日志（LayUI 表格或 API only 首期）。

## Capabilities

### New Capabilities

- `urban-device-telemetry`: 设备心跳、软件状态、客户端错误日志上报与查询。

### Modified Capabilities

- 可选扩展 `sample-data` / 管理仪表盘：增加设备状态卡片（若复用现有 Home 仪表盘）。

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient + UrbanManagement |
| **依赖** | slice 01（主界面底栏）；建议在 03 之后联调 |
| **不包含** | 实时 WebSocket 推送（首期 REST 轮询即可） |
