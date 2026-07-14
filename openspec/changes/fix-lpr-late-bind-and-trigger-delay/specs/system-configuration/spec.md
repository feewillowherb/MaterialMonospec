## ADDED Requirements

### Requirement: LPR 主动抓拍延迟配置

系统 MUST 在 `SystemSettings` 中提供 `TriggerLprCaptureDelayMs` 整型属性，表示启用 LPR 主动抓拍时，在调用设备 `TriggerCaptureAsync` 之前等待的毫秒数。该属性 MUST 通过 JSON 序列化持久化；MUST 在设置窗口「车牌识别设置」区域、「启用 LPR 主动抓拍」控件附近提供可编辑控件。保存时 MUST 将负值规范为 `0`。当 `EnableTriggerLprCapture` 为 `false` 时，延迟配置 MUST NOT 触发任何抓拍。

#### Scenario: 属性默认值

- **WHEN** 创建新的 `SystemSettings` 实例且未显式设置 `TriggerLprCaptureDelayMs`
- **THEN** `TriggerLprCaptureDelayMs` MUST 为 `0`

#### Scenario: 通过设置窗口修改并持久化

- **WHEN** 用户将「主动抓拍延迟(ms)」设为大于 0 的值并保存
- **THEN** 系统 MUST 将 `TriggerLprCaptureDelayMs` 持久化到配置存储

#### Scenario: 旧配置缺字段

- **WHEN** 加载的历史设置 JSON 不含 `TriggerLprCaptureDelayMs`
- **THEN** 反序列化后该属性 MUST 为 `0`

#### Scenario: 抓拍前应用延迟

- **GIVEN** `EnableTriggerLprCapture == true` 且 `TriggerLprCaptureDelayMs == 500`
- **WHEN** 系统进入任一主动抓拍阶段（WaitingForStability / WeightStabilized / OffScale）并准备触发 LPR
- **THEN** 系统 MUST 在调用 `TriggerCaptureAsync` 之前等待约 500 毫秒

#### Scenario: 零延迟不额外等待

- **GIVEN** `EnableTriggerLprCapture == true` 且 `TriggerLprCaptureDelayMs == 0`
- **WHEN** 系统触发 LPR 主动抓拍
- **THEN** 系统 MUST NOT 因延迟配置而插入额外等待
