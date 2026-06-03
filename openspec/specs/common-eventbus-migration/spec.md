# Common EventBus Migration

## Purpose

规范 `MaterialClient.Common` 层服务从 MessageBus 迁移到 ABP ILocalEventBus 的架构要求，确保 Common 层与 ViewModel 层均通过 `ILocalEventBus` 直接通信，禁止桥接回流 MessageBus。

## Requirements

### Requirement: Common 层服务禁止使用 MessageBus.Current.Listen 订阅消息

`MaterialClient.Common` 项目中的所有服务、事件处理器等非 UI 组件 MUST NOT 通过 `MessageBus.Current.Listen<T>()` 订阅任何消息。Common 层服务间通信 MUST 使用 ABP `ILocalEventBus` 进行发布和订阅。

#### Scenario: GateIoControlService 不再订阅 MessageBus

- **WHEN** `GateIoControlService.StartAsync()` 被调用
- **THEN** MUST NOT 调用 `MessageBus.Current.Listen<LicensePlateRecognizedMessage>()`、`MessageBus.Current.Listen<StatusChangedMessage>()` 或 `MessageBus.Current.Listen<SettingsSavedMessage>()`
- **AND** MUST 通过 `ILocalEventBus.Subscribe<LicensePlateRecognizedEventData>()`、`ILocalEventBus.Subscribe<StatusChangedEventData>()`、`ILocalEventBus.Subscribe<SettingsSavedEventData>()` 接收对应事件

#### Scenario: AttendedWeighingService 不再订阅 MessageBus

- **WHEN** `AttendedWeighingService.StartAsync()` 被调用
- **THEN** MUST NOT 调用 `MessageBus.Current.Listen<LicensePlateRecognizedMessage>()`、`MessageBus.Current.Listen<GhostGateSessionResetMessage>()` 或 `MessageBus.Current.Listen<SettingsSavedMessage>()`
- **AND** MUST 通过 `ILocalEventBus` 订阅对应的 `EventData` 类型接收事件

### Requirement: Common 层服务禁止使用 MessageBus.Current.SendMessage 发布消息

`MaterialClient.Common` 项目中的所有服务、事件处理器 MUST NOT 通过 `MessageBus.Current.SendMessage<T>()` 发布消息。所有服务间通信 MUST 使用 `_localEventBus.PublishAsync<TEventData>()`。

#### Scenario: LPR 服务通过 ILocalEventBus 发布车牌识别事件

- **WHEN** `HikvisionLprService` 或 `VzvisionLprService` 的 SDK 回调中检测到车牌识别结果
- **THEN** MUST 调用 `_localEventBus.PublishAsync<LicensePlateRecognizedEventData>(new LicensePlateRecognizedEventData(...))`
- **AND** MUST NOT 调用 `MessageBus.Current.SendMessage<LicensePlateRecognizedMessage>(...)`

#### Scenario: AttendedWeighingService 通过 ILocalEventBus 发布状态变更事件

- **WHEN** `AttendedWeighingService` 需要通知称重状态变更、车牌变更、配送类型变更等业务事件
- **THEN** MUST 调用 `_localEventBus.PublishAsync` 发布对应的 `EventData` 类型
- **AND** MUST NOT 调用 `MessageBus.Current.SendMessage` 发布任何消息

#### Scenario: WeighingMatchingService 通过 ILocalEventBus 发布匹对成功事件

- **WHEN** `WeighingMatchingService.ManualMatchAsync()` 执行手动匹对成功
- **THEN** MUST 调用 `_localEventBus.PublishAsync<MatchSucceededEventData>(...)` 通知匹对结果
- **AND** MUST NOT 调用 `MessageBus.Current.SendMessage<MatchSucceededMessage>(...)`

#### Scenario: TryMatchEventHandler 通过 ILocalEventBus 发布匹对成功事件

- **WHEN** `TryMatchEventHandler` 处理 `TryMatchEvent` 后匹对成功
- **THEN** MUST 调用 `_localEventBus.PublishAsync<MatchSucceededEventData>(...)` 通知匹对结果
- **AND** MUST NOT 调用 `MessageBus.Current.SendMessage<MatchSucceededMessage>(...)`

#### Scenario: GateIoControlService 通过 ILocalEventBus 发布鬼会话重置事件

- **WHEN** `GateIoControlService` 检测到鬼会话并完成重置
- **THEN** MUST 调用 `_localEventBus.PublishAsync<GhostGateSessionResetEventData>(...)` 通知重置事件
- **AND** MUST NOT 调用 `MessageBus.Current.SendMessage<GhostGateSessionResetMessage>(...)`

### Requirement: ABP EventData 类与 Message 类型一一对应

为每种需要迁移的 MessageBus Message 类型 MUST 创建对应的 ABP `EventData` 子类，放在 `MaterialClient.Common/Events/` 目录。EventData 类的属性 MUST 与原 Message 类的属性保持一致。

#### Scenario: EventData 类包含对应 Message 的所有属性

- **WHEN** 创建 `LicensePlateRecognizedEventData`、`StatusChangedEventData`、`PlateNumberChangedEventData`、`DeliveryTypeChangedEventData`、`WeighingRecordCreatedEventData`、`UpdatePlateNumberEventData`、`MatchSucceededEventData`、`SettingsSavedEventData`、`GhostGateSessionResetEventData`
- **THEN** 每个 EventData 类 MUST 继承自 ABP `EventData`
- **AND** 每个 EventData 类 MUST 包含对应 Message 类的所有业务属性

### Requirement: ViewModel 层禁止桥接 EventHandler 将 EventData 中转到 MessageBus

ViewModel 层 MUST 直接消费 ABP `ILocalEventBus` 事件，不得创建“`ILocalEventHandler<T>` 转 `MessageBus.Current.SendMessage()`”的桥接器。现有 UI 事件订阅行为 MUST 通过 `ILocalEventBus` 直接实现并保持业务结果一致。

#### Scenario: 车牌识别事件不再通过桥接转发

- **WHEN** Common 层通过 `ILocalEventBus` 发布 `LicensePlateRecognizedEventData`
- **THEN** ViewModel 层 MUST 直接通过 `ILocalEventBus` 订阅并处理该事件
- **AND** MUST NOT 通过桥接器转换为 `LicensePlateRecognizedMessage` 再转发

#### Scenario: 匹对成功事件不再通过桥接转发

- **WHEN** Common 层通过 `ILocalEventBus` 发布 `MatchSucceededEventData`
- **THEN** ViewModel 层 MUST 直接通过 `ILocalEventBus` 订阅并更新 UI
- **AND** MUST NOT 存在 `MatchSucceededEventData -> MatchSucceededMessage` 的桥接转换链路

### Requirement: 手动匹对业务功能保持完整

迁移过程中 MUST 保持手动匹对机制的完整业务能力，包括 `minWeightDiff=0.1` 阈值、候选记录查询、匹对执行和结果通知。

#### Scenario: 手动匹对执行成功后 UI 收到通知

- **WHEN** 用户在 UI 上执行手动匹对操作（调用 `WeighingMatchingService.ManualMatchAsync`）
- **THEN** 匹对成功后 ViewModel 层 MUST 通过 `ILocalEventBus` 收到 `MatchSucceededEventData`
- **AND** UI MUST 正确显示匹对结果（运单关联更新、状态变更等）

### Requirement: SDK 回调线程安全

LPR 服务的 SDK 回调中发布事件时 MUST 使用 fire-and-forget 模式（`_ = _localEventBus.PublishAsync(...)`），不得阻塞 SDK 回调线程。

#### Scenario: 海康 SDK 回调不阻塞

- **WHEN** `HikvisionLprService` 的 SDK 回调线程中发布 `LicensePlateRecognizedEventData`
- **THEN** MUST 使用 `_ = _localEventBus.PublishAsync(...)` 不等待分发完成
- **AND** SDK 回调线程 MUST 在发布调用后立即返回

#### Scenario: 御道 SDK 回调不阻塞

- **WHEN** `VzvisionLprService` 的 SDK 回调线程中发布 `LicensePlateRecognizedEventData`
- **THEN** MUST 使用 `_ = _localEventBus.PublishAsync(...)` 不等待分发完成
- **AND** SDK 回调线程 MUST 在发布调用后立即返回

### Requirement: Common 层服务停止时正确清理 ILocalEventBus 订阅

迁移后的 Common 层服务 MUST 在 `StopAsync()` 或 `Dispose()` 中正确清理 `ILocalEventBus` 订阅，避免内存泄漏。原有的 `MessageBus` 订阅 Dispose 代码 MUST 同步移除。

#### Scenario: GateIoControlService 停止时清理订阅

- **WHEN** `GateIoControlService.StopAsync()` 被调用
- **THEN** MUST 清理所有通过 `ILocalEventBus.Subscribe` 创建的订阅
- **AND** MUST NOT 包含对已移除的 MessageBus 订阅的 Dispose 调用

#### Scenario: AttendedWeighingService 停止时清理订阅

- **WHEN** `AttendedWeighingService.StopAsync()` 被调用
- **THEN** MUST 清理所有通过 `ILocalEventBus.Subscribe` 创建的订阅
- **AND** MUST NOT 包含对已移除的 MessageBus 订阅的 Dispose 调用
