## Why

Urban 现场常把同一台抓拍机同时配成地磅与成品两条 LPR。SDK 按 IP 只保留一条配置并只发一个 `DeviceName`，现有 `SiteType` 互斥过滤导致识别结果只被一侧消费。需要一次物理识别同时驱动地磅称重与成品通行。

## What Changes

- LPR 识别回调在发布 `LicensePlateRecognizedEventData` 时，按 settings 中**相同 IP** 的全部有效 LPR 配置行扇出：每行一条事件（车牌/图片等相同，`DeviceName` 为该行 `Name`）。
- 地磅与成品/卡口既有 `SiteType` 过滤保持不变，靠扇出自然双边消费。
- 道闸：同一次物理识别不得因扇出重复开闸（短时去重或优先地磅行）。
- 主动触发抓拍：同 IP 多行配置不得对同一物理设备重复 `ForceTrigger`。
- 单 IP 单行或非 Urban 行为保持不变。

## Capabilities

### New Capabilities

- `lpr-shared-ip-event-fanout`: 同 IP 多 LPR 配置行时，一次物理识别扇出多条 `LicensePlateRecognizedEventData`，并约束道闸与主动触发的去重。

### Modified Capabilities

- `lpr-site-type`: 明确同 IP 多站点类型时，扇出后各地点类型仍按本行路由（地磅称重、卡口/成品通行可同时发生）。
- `weighing-device-capture`: 主动触发 LPR 时按物理设备（IP）去重，避免同机重复触发。

## Impact

- **Repos**: MaterialClient（`MaterialClient.Common` LPR 服务、道闸、`WeighingCaptureService`；Urban 通行/称重消费路径依赖事件形状不变）。
- **主要代码**: `VzvisionLprService`、`HikvisionLprService`（及共享发布辅助）、`GateIoControlService`、`WeighingCaptureService`；可选 `LicensePlateRecognitionConfig` 按 IP 查找辅助。
- **非范围**: 不改 SDK 一 IP 一连接模型；不合并两条配置为单行；不改 UrbanManagement 云端契约。
