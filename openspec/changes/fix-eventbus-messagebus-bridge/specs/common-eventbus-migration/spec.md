# common-eventbus-migration

## ADDED Requirements

### Requirement: 桥接器文件必须存在且覆盖完整 EventData→Message 清单

应用层 MUST 在共享层 `MaterialClient.UI/Events/EventBusToMessageBusBridge.cs` 提供全部下列桥接处理器（每个类实现 `ILocalEventHandler<TEventData>, ITransientDependency`，`HandleEventAsync` 内仅 `MessageBus.Current.SendMessage` 对应 `*Message` 后返回，MUST NOT 调度 UI 线程）。该文件 MUST 位于所有宿主（MaterialClient / Urban / Recycle 等）共同依赖的 `MaterialClient.UI` 程序集，不得仅放在单一宿主项目。缺少任一处理器视为实现未完成（不得仅有 Message 类型与 ViewModel Listen 而无桥接）。

清单：
- `LicensePlateRecognizedEventData` → `LicensePlateRecognizedMessage`
- `StatusChangedEventData` → `StatusChangedMessage`
- `PlateNumberChangedEventData` → `PlateNumberChangedMessage`
- `DeliveryTypeChangedEventData` → `DeliveryTypeChangedMessage`
- `WeighingRecordCreatedEventData` → `WeighingRecordCreatedMessage`
- `UpdatePlateNumberEventData` → `UpdatePlateNumberMessage`
- `MatchSucceededEventData` → `MatchSucceededMessage`
- `SettingsSavedEventData` → `SettingsSavedMessage`
- `GhostGateSessionResetEventData` → `GhostGateSessionResetMessage`
- `UploadCompletedEventData` → `UploadCompletedMessage`
- `ServerApprovalSyncedEventData` → `ServerApprovalSyncedMessage`

#### Scenario: 桥接文件存在于 UI 共享层且可被各宿主 ABP 发现

- **WHEN** MaterialClient、MaterialClient.Urban 或 MaterialClient.Recycle 任一宿主启动并完成 ABP 模块初始化
- **THEN** `MaterialClient.UI/Events/EventBusToMessageBusBridge.cs` 中上述全部 `*EventToMessageBusBridge` 类 MUST 作为 `ILocalEventHandler<T>` 注册
- **AND** Common/Urban 发布对应 `*EventData` 时 MUST 触发桥接 `SendMessage`

#### Scenario: Urban 上传完成经桥接抵达 UI

- **WHEN** `UrbanWeighingUploadRequestedEventHandler` 或 `PollingBackgroundService` 发布 `UploadCompletedEventData`
- **THEN** `UploadCompletedEventToMessageBusBridge` MUST 转发为 `UploadCompletedMessage`
- **AND** `UrbanAttendedWeighingViewModel` MUST 能通过已有 `Listen<UploadCompletedMessage>()` 收到并触发重载

#### Scenario: 服务端审批同步经桥接抵达 UI

- **WHEN** `ServerApprovalSyncService` 发布 `ServerApprovalSyncedEventData`
- **THEN** `ServerApprovalSyncedEventToMessageBusBridge` MUST 转发为 `ServerApprovalSyncedMessage`
- **AND** Urban 侧 Listen 端 MUST 能收到该消息

### Requirement: Settings 保存必须经 ILocalEventBus 发布 SettingsSavedEventData

UI 设置保存成功路径 MUST 调用 `_localEventBus.PublishAsync(new SettingsSavedEventData())`（或等价 Publish），MUST NOT 仅依赖 `MessageBus.Current.SendMessage(new SettingsSavedMessage())` 作为唯一通知。`SettingsSavedMessage` MUST 由桥接器从 `SettingsSavedEventData` 转接产生，以便 Common 层（`AttendedWeighingService`、`GateIoControlService` 等）通过 `ILocalEventBus` 订阅与 UI 通过 `Listen<SettingsSavedMessage>` 同时生效。`DetailCloseRequestedMessage` 等纯 VM↔VM 消息仍可直发 MessageBus。

#### Scenario: 设置保存后 Common 与 UI 均收到

- **WHEN** 用户在设置窗口保存成功
- **THEN** MUST 发布 `SettingsSavedEventData` 到 `ILocalEventBus`
- **AND** 桥接器 MUST 转发为 `SettingsSavedMessage`
- **AND** Common 已订阅 `SettingsSavedEventData` 的服务 MUST 收到事件
- **AND** 已 `Listen<SettingsSavedMessage>` 的 ViewModel MUST 收到消息

#### Scenario: 禁止仅 SendMessage 通知设置保存

- **WHEN** 审查 `SettingsWindowViewModel` 保存成功代码路径
- **THEN** MUST NOT 以单独 `SendMessage(SettingsSavedMessage)` 作为唯一通知手段（无 `PublishAsync(SettingsSavedEventData)`）

## MODIFIED Requirements

### Requirement: ViewModel 层禁止桥接 EventHandler 将 EventData 中转到 MessageBus

应用层（`MaterialClient.UI`）MUST 维护 `*EventToMessageBusBridge` 桥接器，将 Common/Urban 层 `ILocalEventBus` 发布的 `*EventData` 转接为 `MessageBus.Current.SendMessage(*Message)`，作为 Common/Urban（`ILocalEventBus`）与 UI（`MessageBus`）之间唯一、可枚举、受保护的适配层。

应用层 MUST 保留 `*EventToMessageBusBridge`（`ILocalEventHandler<TEventData>, ITransientDependency`）桥接器，集中承担「`*EventData` → UI `*Message`」的转接职责。桥接器是**有意的适配层**而非冗余实现：服务层已统一只发布 `ILocalEventBus` 事件数据；UI 层通过 `MessageBus.Current.Listen` 消费对应 `*Message`。删去桥接将使 UI 收不到对应业务通知。桥接器实现 MUST 放在 `MaterialClient.UI/Events/EventBusToMessageBusBridge.cs`（所有宿主共享，不得仅放在单一宿主如 `MaterialClient`），类名以 `*EventToMessageBusBridge` 结尾，由 ABP 按约定自动注册；完整事件清单见「桥接器文件必须存在且覆盖完整 EventData→Message 清单」。

#### Scenario: 车牌识别事件经桥接转发

- **WHEN** Common 层通过 `ILocalEventBus` 发布 `LicensePlateRecognizedEventData`
- **THEN** `LicensePlateRecognizedEventToMessageBusBridge` MUST 调用 `MessageBus.Current.SendMessage(new LicensePlateRecognizedMessage {...})` 转发
- **AND** ViewModel MUST 通过 `MessageBus.Current.Listen<LicensePlateRecognizedMessage>()` 消费，而非直接 `ILocalEventBus.Subscribe`

#### Scenario: 匹配成功事件经桥接转发

- **WHEN** Common 层（`WeighingMatchingService` / `TryMatchEventHandler`）发布 `MatchSucceededEventData`
- **THEN** `MatchSucceededEventToMessageBusBridge` MUST 转发为 `MatchSucceededMessage`
- **AND** MUST 存在 `MatchSucceededEventData -> MatchSucceededMessage` 的桥接转换链路

#### Scenario: 桥接器集中、可枚举

- **WHEN** 排查「某业务事件如何抵达 UI」
- **THEN** 该映射 MUST 仅出现在 `EventBusToMessageBusBridge.cs` 中有限、可列举的处理器集合内
- **AND** MUST 不存在分散在各 ViewModel 内的「`ILocalEventHandler<T>` 转 `SendMessage`」就地桥接

#### Scenario: 缺少桥接文件时视为缺陷

- **WHEN** ViewModel 已 `Listen<*Message>` 且服务层已 `PublishAsync(*EventData)`，但仓库中不存在对应 `*EventToMessageBusBridge`
- **THEN** 该状态 MUST 视为实现缺陷（前端静默收不到事件），不得标记为完成
