## Why

当前项目同时存在 `ILocalEventBus`、MessageBus、以及 EventBus→MessageBus 桥接三套通信路径，造成行为不一致（例如 Urban 端缺桥接时 UI 不更新）与排障复杂度上升。需要统一为单一事件总线 `ILocalEventBus`，消除桥接与双轨通信带来的隐患。

## What Changes

- 将项目内所有业务事件通信统一到 ABP `ILocalEventBus`，移除 `MessageBus.Current.Listen/SendMessage` 作为业务链路依赖。
- 移除 `EventBusToMessageBusBridge` 及等价桥接机制，禁止通过桥接维持双总线并行。
- 将现有 Message 类型对应的业务场景迁移为 `EventData + ILocalEventHandler` 处理模型。
- 更新 ViewModel 与 View 订阅方式：从 MessageBus 订阅改为 `ILocalEventBus` 订阅，确保 UI 更新链路在各模块一致可用。
- **BREAKING**：`viewmodel-messagebus-communication` 规范将从“必须使用 MessageBus”变更为“必须使用 ILocalEventBus”。

## Capabilities

### New Capabilities

- `local-eventbus-only-communication`: 定义“全项目仅允许 ILocalEventBus 事件通信”的统一约束与验收标准。

### Modified Capabilities

- `common-eventbus-migration`: 从“Common 层迁移 + ViewModel 层桥接兼容”升级为“跨层统一 ILocalEventBus，禁止桥接回流 MessageBus”。
- `viewmodel-messagebus-communication`: 将 ViewModel 通信规范改为 `ILocalEventBus`，并移除 MessageBus 依赖条款。

## Impact

- 影响代码：`repos/MaterialClient/src/MaterialClient.Common`、`repos/MaterialClient/src/MaterialClient`、`repos/MaterialClient/src/MaterialClient.Urban`、`repos/MaterialClient/src/MaterialClient.UI`。
- 影响事件模型：保留/扩展 `EventData`，淘汰 UI 侧 Message 类型与桥接 Handler。
- 影响测试与验收：需要覆盖主程序与 Urban 程序在“车牌识别、状态变化、保存完成、关闭请求”等事件链路的端到端验证。
