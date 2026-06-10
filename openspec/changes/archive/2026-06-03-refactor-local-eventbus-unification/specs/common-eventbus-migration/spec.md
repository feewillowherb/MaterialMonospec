## MODIFIED Requirements

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
