# viewmodel-messagebus-communication

## Purpose

定义 ViewModel 间通信的 ILocalEventBus 规范，替代 ReactiveUI MessageBus 与传统 EventHandler 模式，实现松耦合的事件驱动架构。

## Requirements

### Requirement: ViewModel 间通信必须使用 ILocalEventBus

本回退将 ViewModel↔View 通信恢复为 ReactiveUI `MessageBus`，Common 层事件经桥接器转接后以 `*Message` 形式抵达 UI。ViewModel 与 View 之间的事件通信 SHALL 通过 ReactiveUI `MessageBus.Current.SendMessage` / `MessageBus.Current.Listen` 进行，且订阅 SHALL 经 `ObserveOn(RxApp.MainThreadScheduler)` 串行化到主线程后更新 UI。ViewModel 不得使用 `ILocalEventBus.Subscribe<TEventData>` / `ILocalEventHandler<TEventData>` 处理 UI 业务事件——`ILocalEventBus` 的消费由桥接器统一承担。Common 层业务事件经桥接器转接为对应 `*Message` 后，ViewModel 按本规范订阅 `*Message`。

#### Scenario: Detail 操作完成通知

- **WHEN** `AttendedWeighingDetailViewModelBase` 完成保存、作废、匹配、完成等操作（ViewModel→ViewModel 事件）
- **THEN** 必须通过 `MessageBus.Current.SendMessage(new DetailOperationCompletedMessage(...))` 发送通知
- **AND** 订阅端必须通过 `MessageBus.Current.Listen<DetailOperationCompletedMessage>()` 处理，而非 `_localEventBus.PublishAsync` / `ILocalEventHandler<T>`

#### Scenario: 关闭请求通知

- **WHEN** `AttendedWeighingDetailViewModelBase` 或 `SettingsWindowViewModel` 需要请求关闭
- **THEN** 必须通过 `MessageBus.Current.SendMessage(new DetailCloseRequestedMessage())` 发送通知
- **AND** 订阅端必须通过 `MessageBus` 处理关闭请求

#### Scenario: Common 业务事件经桥接抵达 ViewModel

- **WHEN** Common 层（如 `HikvisionLprService`、`WeighingStateManager`）通过 `ILocalEventBus.PublishAsync` 发布 `LicensePlateRecognizedEventData` / `StatusChangedEventData` 等
- **THEN** 桥接器（`*EventToMessageBusBridge`，`ILocalEventHandler<TEventData>`）MUST 将其 `SendMessage` 为对应 `*Message`
- **AND** ViewModel MUST 通过 `MessageBus.Current.Listen<*Message>()` 订阅消费，不得直接 `ILocalEventBus.Subscribe` 该 `*EventData`

### Requirement: 订阅必须使用 ILocalEventBus 并可释放

本回退将订阅恢复为 `MessageBus.Current.Listen` + `ObserveOn(MainThreadScheduler)`，并由 `CompositeDisposable` 统一释放。所有 ViewModel 与 View 的事件订阅 SHALL 使用 `MessageBus.Current.Listen<TMessage>().ObserveOn(RxApp.MainThreadScheduler).Subscribe(...)`，并将返回的 `IDisposable` 收集进与 ViewModel 生命周期绑定的 `CompositeDisposable`，在窗口关闭、`BackToMain`、`Dispose` 时统一释放。涉及 `ObservableCollection`（如 `ListItems`）的 `Clear/Add` 与绑定属性更新 MUST 在 `ObserveOn` 管线内执行，由主线程调度器串行化。

#### Scenario: AttendedWeighingViewModel 订阅 Detail 操作消息

- **WHEN** `AttendedWeighingViewModel` 进入详情视图并开始监听详情操作结果
- **THEN** 必须通过 `MessageBus.Current.Listen<DetailOperationCompletedMessage>().ObserveOn(RxApp.MainThreadScheduler).Subscribe(...)` 订阅
- **AND** 订阅 MUST 收集进 `CompositeDisposable`，在 `BackToMain` 或 `Dispose` 中释放

#### Scenario: SettingsWindow 订阅关闭消息

- **WHEN** `SettingsWindow` 初始化时订阅关闭请求
- **THEN** 必须通过 `MessageBus.Current.Listen<DetailCloseRequestedMessage>()` 订阅（经 `ObserveOn`）
- **AND** 在窗口关闭时释放订阅，避免泄漏

### Requirement: DetailOperationType 枚举定义操作类型

系统 MUST 定义 `DetailOperationType` 枚举，包含 `Save`、`Abolish`、`Match`、`Complete` 四个值，用于在 `DetailOperationCompletedEventData` 中区分操作类型。

#### Scenario: 枚举值与原 event 的映射

- **WHEN** `OperationType` 为 `Save`
- **THEN** 等价于原 `SaveCompleted` event
- **WHEN** `OperationType` 为 `Abolish`
- **THEN** 等价于原 `AbolishCompleted` event
- **WHEN** `OperationType` 为 `Match`
- **THEN** 等价于原 `MatchCompleted` event
- **WHEN** `OperationType` 为 `Complete`
- **THEN** 等价于原 `CompleteCompleted` event

### Requirement: 废弃的 EventArgs 类必须移除

迁移完成后 MUST 删除 `ItemOperationCompletedEventArgs` 类和 `ManualMatchSaveCompletedEventArgs` 类，且不得有任何残留引用。

#### Scenario: 编译验证

- **WHEN** 完成所有迁移步骤
- **THEN** 项目编译必须通过，无任何对已删除 EventArgs 类的引用

### Requirement: UI 串行化仅置于消费侧，禁止在 SDK 回调/生产侧调度 UI 线程

`ObserveOn(RxApp.MainThreadScheduler)` 只能出现在 ViewModel/View 消费侧订阅管线中。生产侧（Common 服务、`ILocalEventHandler`、非托管 SDK 回调）发布事件 MUST 使用线程安全的 `MessageBus.Current.SendMessage` / `_localEventBus.PublishAsync`（SDK 回调为 fire-and-forget），MUST NOT 在生产侧调用 `ObserveOn(RxApp.MainThreadScheduler)` 或 `Dispatcher.UIThread`，以避免应用关闭阶段 UI 线程不可用导致的 SDK Close ↔ UI 线程死锁（见 `repos/MaterialClient/AGENTS.md`）。

#### Scenario: 桥接器不在 HandleEventAsync 内切 UI 线程

- **WHEN** `*EventToMessageBusBridge.HandleEventAsync` 收到 `*EventData`
- **THEN** MUST 直接 `MessageBus.Current.SendMessage(new *Message(...))` 后立即返回
- **AND** MUST NOT 调用 `ObserveOn(RxApp.MainThreadScheduler)` 或 `Dispatcher.UIThread.InvokeAsync`

#### Scenario: ViewModel 消费侧统一串行化

- **WHEN** 同一 `*Message` 被后台多线程经 `SendMessage` 重复触发（如高频车牌/状态变更）
- **THEN** ViewModel 订阅管线 `ObserveOn(RxApp.MainThreadScheduler)` MUST 将回调串行排入主线程队列
- **AND** `ListItems.Clear()/Add()` 等集合操作 MUST 不再依赖手写 `SemaphoreSlim` / `Dispatcher.UIThread.InvokeAsync` 即可避免竞态

### Requirement: Common/Urban 业务事件到达 UI 不得因缺少桥接而静默失败

凡 ViewModel 通过 `MessageBus.Current.Listen<*Message>()` 消费、且对应发布端为 `ILocalEventBus.PublishAsync(*EventData)` 的业务通知，运行时 MUST 存在匹配的 `*EventToMessageBusBridge`。缺少桥接导致 UI 不刷新时，MUST NOT 以「订阅代码已写 Listen」视为功能完成。

#### Scenario: 称重状态变更 UI 必须更新

- **WHEN** `WeighingStateManager`（或等价）发布 `StatusChangedEventData`
- **THEN** 经桥接后 `AttendedWeighingViewModel` / `UrbanAttendedWeighingViewModel` 的 `Listen<StatusChangedMessage>` MUST 收到消息
- **AND** UI 状态展示 MUST 随之更新

#### Scenario: 新建称重记录后列表必须刷新

- **WHEN** `WeighingRecordService` 发布 `WeighingRecordCreatedEventData`
- **THEN** 经桥接后 ViewModel `Listen<WeighingRecordCreatedMessage>` MUST 触发列表刷新（如 `RefreshAsync` / `ReloadRecordsAsync`）

#### Scenario: Urban UploadCompleted / ServerApprovalSynced 必须刷新列表

- **WHEN** 发布 `UploadCompletedEventData` 或 `ServerApprovalSyncedEventData`
- **THEN** 经对应桥接后 `UrbanAttendedWeighingViewModel` MUST 收到 `UploadCompletedMessage` / `ServerApprovalSyncedMessage` 并执行重载
