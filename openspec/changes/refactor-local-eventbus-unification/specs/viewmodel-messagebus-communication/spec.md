## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Message 类型必须遵循项目约定
**Reason**: 事件通信已统一迁移到 `EventData` 模型，MessageBus Message 类型不再作为运行时通信契约。  
**Migration**: 将 `MaterialClient.Common.Events` 下 Message 类迁移为 `EventData`；发布端改用 `PublishAsync`，订阅端改用 `ILocalEventHandler` 或 `Subscribe<TEventData>`。

### Requirement: AGENTS.md 必须新增 MessageBus 编码约定
**Reason**: 规范方向已变更，MessageBus 不再是推荐通信方式。  
**Migration**: 将工程规范更新为“ViewModel 间通信优先使用 ILocalEventBus，禁止新增 MessageBus 通信与桥接”。
