## ADDED Requirements

### Requirement: 稳定后立即匹配配置开关

系统 MUST 在 `WeighingConfiguration` 中提供 `EnableMatchOnStable` 布尔属性，用于控制是否在重量稳定且已有车牌时提前发布运单匹配事件。该属性 MUST 通过现有 `WeighingConfigurationJson` JSON 序列化持久化。系统 MUST 在设置窗口称重参数区域提供标签为「稳定后立即匹配」的 `ToggleSwitch`，供用户修改并随设置保存一并持久化。

#### Scenario: 属性默认值

- **WHEN** 创建新的 `WeighingConfiguration` 实例且未显式设置 `EnableMatchOnStable`
- **THEN** `EnableMatchOnStable` MUST 为 `false`

#### Scenario: 旧配置缺字段

- **WHEN** 加载的历史设置 JSON 不含 `EnableMatchOnStable`
- **THEN** 反序列化后该属性 MUST 为 `false`

#### Scenario: 通过设置窗口启用并持久化

- **WHEN** 用户在称重参数区域打开「稳定后立即匹配」并保存设置
- **THEN** 系统 MUST 将 `EnableMatchOnStable = true` 持久化到配置存储

#### Scenario: 通过设置窗口关闭并持久化

- **WHEN** 用户关闭「稳定后立即匹配」并保存设置
- **THEN** 系统 MUST 将 `EnableMatchOnStable = false` 持久化到配置存储

### Requirement: 稳定且有车牌时提前发布 TryMatchEvent

当 `EnableMatchOnStable` 为 `true`，且称重状态进入 `WeightStabilized` 并成功创建称重记录后，若该记录（或创建时使用的推荐车牌）非空白，系统 MUST 在尊重 `IWeighingPipelineStrategy.ShouldSkipWaybillMatching()` 的前提下发布 `TryMatchEvent(weighingRecordId)`。

#### Scenario: 开关开启且有车牌时稳定后立即匹配

- **GIVEN** `EnableMatchOnStable = true`
- **AND** `ShouldSkipWaybillMatching()` 为 `false`
- **WHEN** 系统完成 `WeightStabilized` 路径的称重记录创建
- **AND** 推荐/记录车牌非空白
- **THEN** 系统 MUST 发布 `TryMatchEvent`，携带该称重记录 ID

#### Scenario: 开关开启但稳定时无车牌则不提前匹配

- **GIVEN** `EnableMatchOnStable = true`
- **WHEN** 系统完成 `WeightStabilized` 路径的称重记录创建
- **AND** 推荐/记录车牌为空或空白
- **THEN** 系统 MUST NOT 在稳定阶段发布 `TryMatchEvent`

#### Scenario: 开关关闭时稳定后不匹配

- **GIVEN** `EnableMatchOnStable = false`
- **WHEN** 系统完成 `WeightStabilized` 路径的称重记录创建
- **THEN** 系统 MUST NOT 因该开关在稳定阶段发布 `TryMatchEvent`
- **AND** 匹配 MUST 仍仅由既有 `OffScale` → `RewriteAndResetCycleAsync` / `TryReWritePlateNumberAsync` 路径触发

#### Scenario: UrbanMode 跳过稳定后匹配

- **GIVEN** `EnableMatchOnStable = true`
- **AND** `ShouldSkipWaybillMatching()` 为 `true`
- **WHEN** 系统完成带非空车牌的稳定记录创建
- **THEN** 系统 MUST NOT 发布 `TryMatchEvent`

### Requirement: 下磅按稳定匹配结果决定是否兜底

当 `EnableMatchOnStable` 为 `true` 时，进入 `OffScale` 的 `TryReWritePlateNumberAsync` 在发布 `TryMatchEvent` 前 MUST 检查本周期称重记录：若 `MatchedId` 非空（稳定时已匹配成功），MUST NOT 再发布 `TryMatchEvent`；若 `MatchedId` 为空（稳定时未尝试或未配上），MUST 按既有非 UrbanMode 规则发布 `TryMatchEvent` 作为兜底。车牌重写与周期重置 MUST 仍执行。当 `EnableMatchOnStable` 为 `false` 时，下磅匹配发布行为 MUST 与现网一致。

#### Scenario: 稳定时已匹配成功则下磅不再匹配

- **GIVEN** `EnableMatchOnStable = true`
- **AND** 本周期记录在下磅时 `MatchedId` 非空
- **WHEN** 系统执行下磅 `TryReWritePlateNumberAsync`
- **THEN** 系统 MUST NOT 发布 `TryMatchEvent`
- **AND** 系统 MUST 仍可执行车牌/收发类型重写与后续周期重置

#### Scenario: 稳定时未匹配则下磅兜底匹配

- **GIVEN** `EnableMatchOnStable = true`
- **AND** `ShouldSkipWaybillMatching()` 为 `false`
- **AND** 本周期记录在下磅时 `MatchedId` 为空
- **WHEN** 系统执行下磅 `TryReWritePlateNumberAsync`
- **THEN** 系统 MUST 发布 `TryMatchEvent`

#### Scenario: 开关关闭时下磅仍按现网发布

- **GIVEN** `EnableMatchOnStable = false`
- **AND** `ShouldSkipWaybillMatching()` 为 `false`
- **WHEN** 系统执行下磅 `TryReWritePlateNumberAsync`
- **THEN** 系统 MUST 按现网逻辑发布 `TryMatchEvent`（不因本开关新增跳过）
