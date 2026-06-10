## Context

当前代码已在 Common 层大量使用 `ILocalEventBus`，但 UI/ViewModel 层仍依赖 ReactiveUI `MessageBus`，并通过 `EventBusToMessageBusBridge` 做跨总线中转。该模式在多入口（如 `MaterialClient` 与 `MaterialClient.Urban`）下存在桥接缺失风险，导致事件能到达日志却无法触发 UI 更新。  
本次变更是跨模块、跨层改造，涉及 `MaterialClient.Common`、`MaterialClient`、`MaterialClient.UI`、`MaterialClient.Urban` 的事件发布与订阅方式统一。

约束：
- 保持现有业务语义不变（车牌识别、状态更新、保存完成、详情关闭等）。
- 不引入新的消息中间件或第三方事件库。
- 迁移期间保证可渐进替换，避免一次性大爆炸改造。

## Goals / Non-Goals

**Goals:**
- 建立“单总线”架构：业务事件仅通过 ABP `ILocalEventBus` 发布与订阅。
- 移除桥接层和 Message 类型在业务链路中的必需性。
- 保证主程序与 Urban 程序事件行为一致，避免“某入口可用、某入口失效”。
- 为后续新增事件提供统一建模规范（`EventData` + `ILocalEventHandler`）。

**Non-Goals:**
- 不重构领域流程本身（称重流程、匹配策略、设备协议不变）。
- 不改造为跨进程/分布式事件总线（仅限本进程本地事件）。
- 不在本变更中引入全新 UI 架构（仅替换事件通信机制）。

## Decisions

1) 采用 `ILocalEventBus` 作为唯一事件通信机制  
- 决策：所有跨服务、跨 ViewModel、View 与 ViewModel 的异步通知统一使用 `ILocalEventBus`。  
- 原因：ABP 内置生命周期与依赖注入一致，减少框架混用。  
- 备选方案：保留 MessageBus 并修复桥接注册。  
  - 放弃原因：仍维持双轨系统，长期维护成本高，且易在新入口重复出现漏注册问题。

2) 以“事件语义迁移”替代“类型名平移”  
- 决策：将现有 Message 类型语义映射到 `EventData`，并由 `ILocalEventHandler<T>` 消费。  
- 原因：避免在 ILocalEventBus 上继续承载“MessageBus 语义包袱”，统一命名和职责边界。  
- 备选方案：继续保留 Message 类，仅改发布通道。  
  - 放弃原因：语义混乱，易造成新代码继续沿用旧抽象。

3) 采用“先并行、后切断”的迁移顺序  
- 决策：先补齐 ILocalEventBus 订阅与发布路径，再删除 MessageBus 监听/发送与桥接文件。  
- 原因：降低回归风险，可分批验证关键链路。  
- 备选方案：一次性删除 MessageBus 并全量替换。  
  - 放弃原因：排障面过大，定位回归困难。

4) UI 线程调度在 Handler 或订阅端显式处理  
- 决策：对需要更新 UI 的处理逻辑保留主线程调度（等价于原 `ObserveOn(RxApp.MainThreadScheduler)` 语义）。  
- 原因：避免跨线程 UI 更新异常。  
- 备选方案：默认在事件处理线程直接更新。  
  - 放弃原因：不满足 Avalonia/ReactiveUI 的线程安全要求。

## Risks / Trade-offs

- [风险] 事件注册遗漏导致局部功能失效 → [缓解] 建立“事件发布点/订阅点”清单并逐条验收，迁移后全局搜索 `MessageBus.Current` 与桥接类名应为 0（允许测试桩除外）。  
- [风险] UI 线程切换丢失引发异常 → [缓解] 为涉及 UI 绑定字段更新的 handler 增加主线程调度约束与集成测试。  
- [风险] 并行迁移期间双重触发 → [缓解] 在切换窗口期为关键事件加去重保护或临时开关，完成切换后移除。  
- [权衡] 迁移初期代码改动面大 → [收益] 后续新增入口无需桥接，架构一致性明显提升。

## Migration Plan

1. 盘点并冻结事件清单：发布点、订阅点、桥接点、Message 类型。  
2. 为仍依赖 MessageBus 的链路补齐 `EventData + ILocalEventHandler`。  
3. 分模块迁移订阅端（主程序、Urban、UI 窗口与 ViewModel）。  
4. 分模块迁移发布端，保证不再发送 MessageBus 消息。  
5. 删除 `EventBusToMessageBusBridge` 与不再使用的 Message 类型。  
6. 执行回归：LPR 车牌刷新、状态栏更新、详情操作完成、设置保存关闭、手动匹配结果。  
7. 通过编译与集成测试后合并。

回滚策略：
- 保留小步提交；若出现阻断问题，可回退到“桥接仍在但新订阅已就绪”的中间版本。  
- 不做数据结构变更，无需数据库回滚。

## Open Questions

- `ILocalEventBus.Subscribe` 返回订阅句柄在各模块的统一释放模式是否需要封装成公共基类？  
- 已有 `Message` 类是否全部删除，还是保留仅用于历史兼容（建议删除，减少歧义）？  
- UI 层是否统一引入事件订阅适配器以减少重复样板代码？
