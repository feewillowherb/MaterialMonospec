# Recycle Receiving Confirmation

## Purpose

定义 Recycle 模式收货确认功能，替换打印按钮，支持录入收货时间和上传收货照片。

## Requirements

### Requirement: Recycle 模式收货按钮替换打印按钮
`AttendedWeighingViewModel` SHALL 在 `WeighingMode.Recycle` 且选中已完成 Waybill 时，将主列表行操作的「打印」按钮替换为「收货」按钮；SHALL NOT 在 Recycle 模式显示打印入口。SolidWaste 模式的打印行为保持不变。

#### Scenario: Recycle 已完成运单显示收货按钮
- **WHEN** 选中 `WeighingMode.Recycle` 且 `OrderType=Completed` 的 Waybill
- **THEN** 主列表行操作 SHALL 显示「收货」按钮
- **AND** SHALL NOT 显示「打印」按钮

#### Scenario: SolidWaste 模式保留打印按钮
- **WHEN** 选中 `WeighingMode.SolidWaste` 且 `OrderType=Completed` 的 Waybill
- **THEN** 主列表行操作 SHALL 显示「打印」按钮（行为不变）
- **AND** SHALL NOT 显示「收货」按钮

#### Scenario: 非已完成运单不显示收货按钮
- **WHEN** 选中 Recycle 但 `OrderType` 不为 `Completed` 的 Waybill
- **THEN** SHALL NOT 显示「收货」按钮

### Requirement: 收货对话框录入收货时间
点击「收货」按钮 SHALL 弹出收货确认对话框，要求录入 `receivingTime`（收货时间）。`receivingTime` SHALL 通过日期+时间选择控件录入，格式为 `yyyy-MM-dd HH:mm:ss`。

#### Scenario: 录入收货时间
- **WHEN** 用户在收货对话框选择收货时间为 `2026-07-09 15:20`
- **THEN** `receivingTime` SHALL 记录为 `"2026-07-09 15:20:00"`

#### Scenario: 收货时间为必填
- **WHEN** 用户未选择收货时间即点击「确认收货」
- **THEN** SHALL 阻止确认
- **AND** SHALL 提示收货时间为必填

### Requirement: 收货照片上传为 TicketPhoto 附件
收货对话框 SHALL 提供图片上传控件录入 `receivingProof`。上传的图片 SHALL 作为 `AttachmentFile` 持久化，其 `AttachType` SHALL 为 `TicketPhoto`，并经 `WaybillAttachment` 关联到当前 Waybill。

#### Scenario: 上传收货照片生成 TicketPhoto 附件
- **WHEN** 用户选择一张图片并确认收货
- **THEN** 系统 SHALL 创建一条 `AttachmentFile`，`AttachType = TicketPhoto`
- **AND** SHALL 经 `AttachmentService` 落盘并记录 `LocalPath`
- **AND** SHALL 创建 `WaybillAttachment` 将该附件关联到当前 Waybill

#### Scenario: 收货照片为必填
- **WHEN** 用户未上传收货照片即点击「确认收货」
- **THEN** SHALL 阻止确认
- **AND** SHALL 提示收货照片为必填

#### Scenario: 复用既有 TicketPhoto 枚举值
- **WHEN** 创建收货附件
- **THEN** SHALL 使用既有 `AttachType.TicketPhoto`（=3）
- **AND** SHALL NOT 新增枚举值

### Requirement: 收货数据持久化并标记待上报
确认收货 SHALL 将 `receivingTime` 写入 `Waybill`（新增可空列），将收货附件持久化，并对该 Waybill 调用 `SetPendingSync()`，使后台 `RecycleDataSyncService` 在下轮采集 `receivingProof` 并上报 §2.2 `receivingTime`/`receivingProof`。

#### Scenario: 收货时间持久化到 Waybill
- **WHEN** 用户确认收货
- **THEN** `Waybill.ReceivingTime` SHALL 被设为录入值
- **AND** 该 Waybill SHALL 被标记为待上报（`IsPendingSync = true`）

#### Scenario: 已收货运单可重复收货覆盖
- **WHEN** 对已有 `ReceivingTime` 的 Waybill 再次收货
- **THEN** SHALL 以新的 `receivingTime` 与收货附件覆盖原值
- **AND** SHALL 记录覆盖日志

### Requirement: 收货服务经 ABP 约定注册
收货领域服务（如 `IRecycleReceivingService`）SHALL 实现 ABP 依赖接口并标注 `[AutoConstructor]`，由 ABP 按约定扫描注册，SHALL NOT 在 Module 中显式注册。数据写入方法 SHALL 使用 `[UnitOfWork]`。

#### Scenario: 从 DI 解析收货服务
- **WHEN** ViewModel 从服务提供者请求收货服务
- **THEN** 实现 SHALL 被解析
- **AND** `Waybill`/`AttachmentFile`/`WaybillAttachment` 仓储经构造函数注入

#### Scenario: 收货写入事务边界
- **WHEN** 收货确认执行写入
- **THEN** 方法 SHALL 标注 `[UnitOfWork]`
- **AND** 异常时 SHALL 触发事务回滚（不残留半成品附件关联）
