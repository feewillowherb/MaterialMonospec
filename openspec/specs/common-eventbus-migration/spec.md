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

