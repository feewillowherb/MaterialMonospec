# common-eventbus-migration

## MODIFIED Requirements

### Requirement: ViewModel 层禁止桥接 EventHandler 将 EventData 中转到 MessageBus

> 回退为：应用层（`MaterialClient`）MUST 维护 `*EventToMessageBusBridge` 桥接器，将 Common 层 `ILocalEventBus` 发布的 `*EventData` 转接为 `MessageBus.Current.SendMessage(*Message)`，作为 Common（`ILocalEventBus`）与 UI（`MessageBus`）之间唯一、可枚举、受保护的适配层。

应用层 MUST 保留 `*EventToMessageBusBridge`（`ILocalEventHandler<TEventData>, ITransientDependency`）桥接器，集中承担「Common `*EventData` → UI `*Message`」的转接职责。桥接器是**有意的适配层**而非冗余实现：Common 服务（`HikvisionLprService`、`VzvisionLprService`、`WeighingStateManager`、`AttendedWeighingService`、`GateIoControlService`、`MaterialPlatformBearerTokenHandler` 等）已统一只发布 `ILocalEventBus` 事件数据；UI 层（`AttendedWeighingViewModel` 等）通过 `MessageBus.Current.Listen` 消费对应 `*Message`。删去桥接将使 UI 收不到对应业务通知，或迫使每个 ViewModel 直接订阅 `ILocalEventBus` 并自行处理线程/防抖（第二版本的竞态根因）。桥接器实现 MUST 放在 `MaterialClient/Events/EventBusToMessageBusBridge.cs`，类名以 `*EventToMessageBusBridge` 结尾，由 ABP 按约定自动注册。

#### Scenario: 车牌识别事件经桥接转发

- **WHEN** Common 层通过 `ILocalEventBus` 发布 `LicensePlateRecognizedEventData`
- **THEN** `LicensePlateRecognizedEventToMessageBusBridge` MUST 调用 `MessageBus.Current.SendMessage(new LicensePlateRecognizedMessage {...})` 转发
- **AND** ViewModel MUST 通过 `MessageBus.Current.Listen<LicensePlateRecognizedMessage>()` 消费，而非直接 `ILocalEventBus.Subscribe`

#### Scenario: 匹配成功事件经桥接转发

- **WHEN** Common 层（`WeighingMatchingService` / `TryMatchEventHandler`）发布 `MatchSucceededEventData`
- **THEN** `MatchSucceededEventToMessageBusBridge` MUST 转发为 `MatchSucceededMessage`
- **AND** MUST 存在 `MatchSucceededEventData -> MatchSucceededMessage` 的桥接转换链路（与第二版本「禁止桥接」相反）

#### Scenario: 桥接器集中、可枚举

- **WHEN** 排查「某业务事件如何抵达 UI」
- **THEN** 该映射 MUST 仅出现在 `EventBusToMessageBusBridge.cs` 中有限、可列举的处理器集合内
- **AND** MUST 不存在分散在各 ViewModel 内的「`ILocalEventHandler<T>` 转 `SendMessage`」就地桥接
