## Why

Urban 桌面端在主界面内展示称重记录并写入 **WeighingRecord**，不参与运单匹对。需将设备重量事件与 **WeighingSystemViewModel**（列表、重量区、状态文案）联动。

## What Changes

- **复用 `MaterialClient.Common` 中 AttendedWeighing 既有逻辑**（如 `AttendedWeighingService` 及既有事件/落库路径）驱动 UrbanMode 下称重；仅在 Urban 与有人值守差异处**扩展**（策略、条件分支或薄适配层），避免重复实现称重状态机。
- **`IUrbanWeighingService`**（或等价）：在 AttendedWeighing 产出路径上保证 `WeighingMode = UrbanMode`、`ProductCode = 5030`。
- **`IWeighingPipelineStrategy` Urban 实现**（或与 AttendedWeighing 集成的守卫）：跳过 waybill 匹对。
- 复用称重设备 / `IWeightSource`；重量稳定后更新主界面大号重量显示与「称重已结束」等状态。
- **`WeighingSystemViewModel`**：绑定记录列表（Tab：全部/正常/异常）、筛选、分页；数据来自本地 SQLite（与 AttendedWeighing 写入一致）。
- 同步状态字段（Pending/Synced/Failed）供 slice 03 上传。

## Capabilities

### New Capabilities

- `urban-weighing-record-pipeline`: 主界面称重管线 + ViewModel 绑定，无 waybill。

### Modified Capabilities

- `attended-weighing`（Common）：UrbanMode 下经 **AttendedWeighing 既有路径**落库；通过守卫/策略 **不进入** waybill 匹对；若需共用扩展点，在 OpenSpec delta 中写明对 Common 的最小修改范围。

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient |
| **依赖** | slice 01 主窗口与 ViewModel 骨架 |
| **UI** | `WeighingSystemWindow` 列表与重量区 |
