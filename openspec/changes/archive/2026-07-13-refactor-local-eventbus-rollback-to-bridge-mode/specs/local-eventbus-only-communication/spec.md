# local-eventbus-only-communication

## REMOVED Requirements

### Requirement: 全项目事件通信必须仅使用 ILocalEventBus

**Reason**: 本能力由 `2026-06-03-refactor-local-eventbus-unification` 整体新增，其核心约束「运行时代码仅 `ILocalEventBus`、禁止 `MessageBus.Current`、禁止任何 EventBus→MessageBus 桥接」与本次回滚（恢复桥接模式）直接冲突。回滚后 Common 层继续用 `ILocalEventBus`，但 UI 层恢复经桥接消费 ReactiveUI `MessageBus`，单总线前提不再成立。

**Migration**: 删除该 Requirement（连同两个 Scenario）。桥接与分层职责改由两条能力分别承载：
- `common-eventbus-migration`：Common 层（基础设施/服务）仅用 `ILocalEventBus`，并维护 `*EventData` ↔ `*Message` 一一对应；
- `viewmodel-messagebus-communication`：UI 层（ViewModel/View）经 `MessageBus.Listen` + `ObserveOn(RxApp.MainThreadScheduler)` 消费经桥接转接的事件，并强制 UI 串行化置于消费侧。
