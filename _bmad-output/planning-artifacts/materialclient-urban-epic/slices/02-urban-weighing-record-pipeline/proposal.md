## Why

Urban 采集端只需产生并保存 **WeighingRecord**，不参与运单匹对。需在无 UI 前提下接入称重硬件/重量源，并以 **UrbanMode (201)** 写入记录。

## What Changes

- 实现 **`IUrbanWeighingService`**（或等价应用服务）：创建 `WeighingRecord`，设置 `WeighingMode = UrbanMode`、`ProductCode = 5030`。
- 注册 **`IWeighingPipelineStrategy`** 的 Urban 实现：**跳过** waybill 匹对、`WeighingMatchingService`、运单同步。
- 复用现有称重设备/重量读数基础设施（与 MaterialClient 共享 Infrastructure）。
- 提供 **headless 触发** 机制：集成测试入口、或 `BackgroundService` 订阅重量稳定事件（无 Avalonia ViewModel）。
- 本地 SQLite 持久化 WeighingRecord；标记同步状态字段（`SyncStatus` / 扩展列，与 slice 03 对齐）。

## Capabilities

### New Capabilities

- `urban-weighing-record-pipeline`: UrbanMode 下仅 WeighingRecord 的称重管线，无 waybill。

### Modified Capabilities

- 若存在 `attended-weighing` / 称重匹配相关 spec：明确 **UrbanMode 不调用** 匹对流程（文档 + 代码守卫）。

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient |
| **依赖** | slice 01 已完成 Urban 宿主可启动 |
| **不包含** | HTTP 上传、UrbanManagement API |
