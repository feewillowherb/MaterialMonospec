## Context

主客户端称重流程可能在重量稳定后触发 waybill 匹对。Urban 必须截断该分支。

## Goals / Non-Goals

**Goals**

- 重量稳定 → 单条 `WeighingRecord` 落库
- 模式与产品码正确
- 可自动化测试（无 UI）

**Non-Goals**

- Waybill CRUD、手动匹对窗
- 上传服务端

## Decisions

1. **策略模式**：`IWeighingPipelineStrategy.OnWeightStableAsync()` Urban 实现只 `Insert WeighingRecord`。
2. **守卫**：`if (mode == UrbanMode) return;` 在共享匹对入口，防止误调用。
3. **Headless 触发**：`UrbanWeighingBackgroundService` 订阅 `IWeightSource` / 现有设备事件总线（ILocalEventBus）。
4. **实体字段**：复用 `WeighingRecord`；新增或使用现有 `SyncState` 枚举：`Pending` / `Synced` / `Failed`。
5. **测试**：BDD/集成测试 — Mock 重量 → 断言 DB 一条记录、Mode=201。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 共享流程隐式依赖 waybill | 代码审查 + Urban 集成测试 |
| 无 UI 无法现场操作 | 文档说明首期靠设备自动称重或测试钩子 |
