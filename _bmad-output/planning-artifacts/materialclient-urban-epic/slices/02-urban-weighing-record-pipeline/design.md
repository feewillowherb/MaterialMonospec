## Context

主界面已存在（slice 01）。称重逻辑须驱动 UI；**以 `MaterialClient.Common` 的 AttendedWeighing 既有实现为基线**，Urban 仅做注册、配置与 UrbanMode 分支扩展。

## Goals / Non-Goals

**Goals**

- 重量稳定 → DB 一条 WeighingRecord → 列表刷新
- 重量区实时显示（绑定 `CurrentWeight`）
- Mode=201 / ProductCode=5030

**Non-Goals**

- Waybill、上传 HTTP

## Decisions

1. **称重基线**：Urban 宿主注册并启动 **AttendedWeighing** 与主程序相同或子集的 ABP 模块依赖；称重记录创建走 Common 既有服务/事件。若 UrbanMode 需跳过运单，在 **策略接口或 `WeighingMode == UrbanMode` 守卫** 处短路，而非复制 `AttendedWeighingService` 主体。
2. **扩展边界**：新增代码优先放在 **扩展点**（如 `IWeighingPipelineStrategy`、Urban 专用 `UrbanWeighingModule` 配置）；确需改 Common 时保持对有人值守行为的回归测试。
3. **ViewModel**：订阅 AttendedWeighing / `ILocalEventBus` 已有事件（如 `WeighingRecordCreated`）或 ReactiveUI `WhenAnyValue` 刷新 `ObservableCollection` 与选中行。
4. **列表**：复用 Demo 列（车牌、称重时间、重量、状态）；「审批」按钮 Urban 首期改为「详情」或隐藏，与产品确认。
5. **筛选**：称重时间、车牌 — 查询本地仓储。
6. **测试**：ViewModel 单元测试 + 设备 Mock 集成测试。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| UI 线程与设备回调 | `ObserveOn(RxApp.MainThreadScheduler)` |
| 共享流程隐式依赖 waybill | UrbanMode 守卫 + 有人值守回归测试 |
| AttendedWeighing 与 Urban 耦合过紧 | 扩展点集中在 Urban 模块；Common 改动保持最小 |
