## ADDED Requirements

### Requirement: 全项目事件通信必须仅使用 ILocalEventBus
项目内运行时代码中的业务事件发布与订阅 MUST 仅使用 ABP `ILocalEventBus`。除测试桩外，运行时代码 MUST NOT 使用 `MessageBus.Current.SendMessage`、`MessageBus.Current.Listen`，也 MUST NOT 依赖任何 EventBus→MessageBus 桥接器。

#### Scenario: 新增事件链路遵循单总线
- **WHEN** 开发者新增一条跨组件事件通知链路
- **THEN** 该链路 MUST 使用 `EventData` + `ILocalEventHandler<T>` + `ILocalEventBus.PublishAsync` 实现
- **AND** MUST NOT 引入或复用 MessageBus 作为中间通道

#### Scenario: 存量桥接被移除
- **WHEN** 本变更完成并通过验收
- **THEN** 代码库运行时代码中 MUST 不存在 EventBus→MessageBus 的桥接实现与注册
- **AND** 主程序与 Urban 程序对同一事件语义 MUST 使用一致的 ILocalEventBus 机制
