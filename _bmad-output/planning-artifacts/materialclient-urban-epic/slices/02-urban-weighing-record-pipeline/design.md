## Context

主界面已存在（slice 01）。称重逻辑须驱动 UI 而非 headless 后台。

## Goals / Non-Goals

**Goals**

- 重量稳定 → DB 一条 WeighingRecord → 列表刷新
- 重量区实时显示（绑定 `CurrentWeight`）
- Mode=201 / ProductCode=5030

**Non-Goals**

- Waybill、上传 HTTP

## Decisions

1. **策略**：`UrbanWeighingPipelineStrategy.OnWeightStableAsync` 仅 Insert + 发布 `WeighingRecordCreated` 事件。
2. **ViewModel**：订阅事件 / ReactiveUI `WhenAnyValue` 刷新 `ObservableCollection` 与选中行。
3. **列表**：复用 Demo 列（车牌、称重时间、重量、状态）；「审批」按钮 Urban 首期改为「详情」或隐藏，与产品确认。
4. **筛选**：称重时间、车牌 — 查询本地仓储。
5. **测试**：ViewModel 单元测试 + 设备 Mock 集成测试。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| UI 线程与设备回调 | `ObserveOn(RxApp.MainThreadScheduler)` |
