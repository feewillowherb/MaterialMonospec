# viewmodel-messagebus-communication

## Purpose

定义 ViewModel 间通信的 ILocalEventBus 规范，替代 ReactiveUI MessageBus 与传统 EventHandler 模式，实现松耦合的事件驱动架构。

## Requirements

### Requirement: ViewModel 间通信必须使用 ILocalEventBus

ViewModel 之间的事件通信 SHALL 通过 ABP `ILocalEventBus` 进行。禁止在 ViewModel 中使用 `MessageBus.Current.SendMessage`、`MessageBus.Current.Listen` 作为业务通信机制，也禁止声明 `public event` 或委托订阅模式替代。

#### Scenario: Detail 操作完成通知

- **WHEN** `AttendedWeighingDetailViewModelBase` 完成保存、作废、匹配、完成等操作
- **THEN** 必须通过 `_localEventBus.PublishAsync(new DetailOperationCompletedEventData(...))`（或等价 EventData）发送通知
- **AND** 必须通过 `ILocalEventHandler<DetailOperationCompletedEventData>` 在订阅端处理，而非 `MessageBus.Current.SendMessage`

#### Scenario: 关闭请求通知

- **WHEN** `AttendedWeighingDetailViewModelBase` 或 `SettingsWindowViewModel` 需要请求关闭
- **THEN** 必须通过 `_localEventBus.PublishAsync(new DetailCloseRequestedEventData())`（或等价 EventData）发送通知
- **AND** 订阅端必须通过 `ILocalEventBus` 处理关闭请求

### Requirement: 订阅必须使用 ILocalEventBus 并可释放

所有 ViewModel 与 View 的事件订阅 SHALL 使用 `ILocalEventBus.Subscribe<TEventData>(...)` 或 `ILocalEventHandler<TEventData>`，并在窗口关闭、ViewModel 销毁或 `StopAsync/Dispose` 时完成释放。

#### Scenario: AttendedWeighingViewModel 订阅 Detail 操作消息

- **WHEN** `AttendedWeighingViewModel` 进入详情视图并开始监听详情操作结果
- **THEN** 必须通过 `ILocalEventBus` 订阅 `DetailOperationCompletedEventData`
- **AND** 在 `BackToMain` 或销毁流程中必须释放对应订阅

#### Scenario: SettingsWindow 订阅关闭消息

- **WHEN** `SettingsWindow` 初始化时订阅关闭请求
- **THEN** 必须通过 `ILocalEventBus` 订阅 `DetailCloseRequestedEventData`（或等价事件）
- **AND** 在窗口关闭时必须释放订阅，避免泄漏

### Requirement: DetailOperationType 枚举定义操作类型

必须定义 `DetailOperationType` 枚举，包含 `Save`、`Abolish`、`Match`、`Complete` 四个值，用于在 `DetailOperationCompletedEventData` 中区分操作类型。

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
