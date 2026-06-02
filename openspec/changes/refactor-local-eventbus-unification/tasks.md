## 1. 事件资产盘点与迁移准备

- [ ] 1.1 盘点 `MaterialClient.Common`、`MaterialClient`、`MaterialClient.UI`、`MaterialClient.Urban` 中所有 `MessageBus.Current.Listen/SendMessage` 使用点并形成迁移清单
- [ ] 1.2 盘点所有 EventBus→MessageBus 桥接类（含注册位置）并标记删除顺序
- [ ] 1.3 建立 Message 类型到 EventData 的一对一映射表，确认缺失 EventData 并补齐定义

## 2. 发布端迁移到 ILocalEventBus

- [ ] 2.1 将 ViewModel/Service 中 `MessageBus.Current.SendMessage` 发布逻辑替换为 `_localEventBus.PublishAsync`（保持原业务语义）
- [ ] 2.2 为详情完成、关闭请求、设置保存、匹配完成等 UI 侧消息补齐对应 EventData 发布
- [ ] 2.3 确保 SDK 回调等高频路径采用非阻塞发布模式（fire-and-forget）并补充必要日志

## 3. 订阅端迁移到 ILocalEventBus

- [ ] 3.1 将各 ViewModel 中 `MessageBus.Current.Listen<T>` 订阅替换为 `ILocalEventBus.Subscribe<TEventData>` 或 `ILocalEventHandler<TEventData>`
- [ ] 3.2 对涉及 UI 绑定更新的事件处理补齐主线程调度，避免跨线程更新 UI
- [ ] 3.3 为窗口关闭与 ViewModel 销毁流程统一实现订阅释放，避免内存泄漏

## 4. 移除桥接与旧消息契约

- [ ] 4.1 删除 `EventBusToMessageBusBridge` 及其依赖注册，确保运行时不再存在桥接链路
- [ ] 4.2 删除不再使用的 Message 类型与引用（仅保留测试场景需要的最小兼容桩）
- [ ] 4.3 更新注释与文档中关于 MessageBus 的表述，统一为 ILocalEventBus 规范

## 5. 验证与回归

- [ ] 5.1 执行编译与静态检查，确认运行时代码中不再出现 `MessageBus.Current`（测试桩除外）
- [ ] 5.2 回归主程序关键链路：LPR 车牌刷新、状态变化、详情操作完成、手动匹配结果同步
- [ ] 5.3 回归 Urban 程序关键链路：`/api/lpr/test-plate` 注入后 UI 车牌实时更新、设置保存相关联动
- [ ] 5.4 记录迁移结果与残留风险，补充后续优化项（如订阅封装基类）
