## Why

称重稳定后立即创建 `WeighRecord` 并快照绑定 LPR 路径，而海康/Vz 主动抓拍结果经 SDK 异步回调晚到，无法回绑，Urban 常被标成缺图异常。同周期还会混入无车牌兜底图，需要「有车牌优先」；现场还需要可配置的主动抓拍前延迟（毫秒），以便车辆停稳后再触发识别。

## What Changes

- LPR 附件绑定与 `WeighRecord` 创建时序解耦：建单前已有路径照常绑定；建单后本周期内晚到路径 MUST 补绑/升级到同一记录。
- **全客户端**（Standard / SolidWaste / Recycle / Urban）均落盘并挂接 `AttachType.Lpr`；去掉仅 `UrbanMode` / 无 `CameraConfigs` 才保存绑定的门禁。非 Urban 客户端可不展示、不消费该附件。
- 本周期 LPR 候选择优：有车牌结果的图片优先级高于无车牌；同级可被较新候选覆盖。
- 设置中新增 `TriggerLprCaptureDelayMs`（主动抓拍延迟，毫秒），默认 `0`；启用主动抓拍时在调用 `TriggerCaptureAsync` 前等待该时长。
- 设置窗口「车牌识别设置」区在「启用 LPR 主动抓拍」附近增加延迟输入并持久化。
- 补绑成功后，若存在 Urban 扩展且曾因缺图异常，SHOULD 重算 `IsAnomaly` / `AnomalyReason`（仅 Urban）。

## Capabilities

### New Capabilities

（无。行为变更落在现有 capability。）

### Modified Capabilities

- `license-plate-recognition`：全模式 LPR 落盘与挂接；本周期候选择优；建单后补绑/Upsert；下磅重置后不得串绑。
- `system-configuration`：新增 `TriggerLprCaptureDelayMs` 配置与设置 UI。

## Impact

- **MaterialClient.Common**：`WeighingStateManager`、`AttendedWeighingService`、`WeighingRecordService`、`WeighingCaptureService`、`HikvisionLprService` / `VzvisionLprService`（放宽落盘门禁）、`SystemSettings`。
- **MaterialClient.UI**：`SettingsWindow.axaml`、`SettingsWindowViewModel`。
- **各产品客户端 UI**：Recycle / SolidWaste / Standard **无需**为展示 LPR 改 UI；Urban 继续使用现有展示与异常逻辑。
- **Urban 异常**：补绑后可能刷新 `UrbanWeighingExtension.IsAnomaly`。
- **非 BREAKING**：旧设置缺少延迟字段时视为 `0`；非 Urban 仅多存 `AttachType.Lpr` 数据，既有 UI 不强制消费。
