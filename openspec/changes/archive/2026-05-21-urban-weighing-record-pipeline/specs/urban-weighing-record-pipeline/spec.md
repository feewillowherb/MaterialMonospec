## ADDED Requirements

### Requirement: AttendedWeighingService 内部扩展 UrbanMode 支持

AttendedWeighingService SHALL 在内部查询当前 `WeighingMode`，并在 `ProcessStatusTransition` 中根据模式走不同分支。当 `WeighingMode = UrbanMode (201)` 时，跳过 `TryMatchEvent` 相关的触发链路。

#### Scenario: UrbanMode 状态转换跳过匹对
- **WHEN** `ProcessStatusTransition` 处理状态转换
- **AND WHEN** 当前 `WeighingMode = UrbanMode (201)`
- **THEN** SHALL NOT 触发 `RewriteAndResetCycleAsync` 中的 `TryMatchEvent` 发布
- **AND** SHALL 执行车牌重写和周期重置（保留这部分逻辑）
- **AND** SHALL 记录 Debug 日志表明处于 UrbanMode 分支

#### Scenario: 非 UrbanMode 保持现有行为
- **WHEN** `ProcessStatusTransition` 处理状态转换
- **AND WHEN** 当前 `WeighingMode` 不为 UrbanMode
- **THEN** SHALL 保持现有全部行为不变（包括 TryMatchEvent）

### Requirement: WeighingRecordService 内部模式感知

WeighingRecordService SHALL 在内部查询当前 `WeighingMode`，在 `TryReWritePlateNumberAsync` 中根据模式决定是否发布 `TryMatchEvent`。

#### Scenario: UrbanMode 不发布 TryMatchEvent
- **WHEN** `TryReWritePlateNumberAsync` 执行完成
- **AND WHEN** 当前 `WeighingMode = UrbanMode (201)`
- **THEN** SHALL NOT 调用 `_localEventBus.PublishAsync(new TryMatchEvent(...))`
- **AND** SHALL 记录 Debug 日志表明跳过了匹对

#### Scenario: 非 UrbanMode 正常发布 TryMatchEvent
- **WHEN** `TryReWritePlateNumberAsync` 执行完成
- **AND WHEN** 当前 `WeighingMode` 不为 UrbanMode
- **THEN** SHALL 正常发布 `TryMatchEvent`（保持现有行为不变）

### Requirement: ViewModel 订阅 ILocalEventBus 已有事件

WeighingSystemViewModel SHALL 通过 `ILocalEventBus` 订阅 `WeighingRecordCreatedEventData` 和 `StatusChangedEventData`，驱动 UI 更新。不新建 MessageBus 消息类型。

#### Scenario: 订阅 WeighingRecordCreatedEventData 刷新列表
- **WHEN** ViewModel 初始化完成
- **THEN** SHALL 通过 `ILocalEventBus.Subscribe<WeighingRecordCreatedEventData>` 订阅记录创建事件
- **AND** 收到事件后 SHALL 从本地仓储查询完整记录并添加到 WeighingRecords 集合顶部

#### Scenario: 订阅 StatusChangedEventData 更新状态文案
- **WHEN** ViewModel 初始化完成
- **THEN** SHALL 通过 `ILocalEventBus.Subscribe<StatusChangedEventData>` 订阅状态变更事件
- **AND** 收到事件后 SHALL 更新 WeightStatus 和 WeightStatusColor

#### Scenario: 列表更新在 UI 线程执行
- **WHEN** 收到 ILocalEventBus 事件
- **THEN** SHALL 通过 ObserveOn(RxApp.MainThreadScheduler) 确保在 UI 线程更新集合

### Requirement: 实时更新重量区显示

WeighingSystemViewModel SHALL 实时绑定称重设备的当前重量值到主界面重量区。

#### Scenario: 重量实时更新
- **WHEN** 称重设备推送新重量值 8500kg
- **THEN** SHALL 在 500ms 内更新 CurrentWeight 为 "8,500"
- **AND** SHALL 通过 ReactiveUI 属性变更通知 UI

#### Scenario: 无设备数据时显示零
- **WHEN** 称重管线未启动或设备断开
- **THEN** SHALL 显示 CurrentWeight 为 "0.00"

### Requirement: 状态文案联动

WeighingSystemViewModel SHALL 根据称重状态显示对应文案和颜色。

#### Scenario: 等待上磅状态
- **WHEN** 称重状态为 OffScale
- **THEN** SHALL 显示 WeightStatus = "等待上磅"
- **AND** SHALL 设置 WeightStatusColor = "#94A3B8"（灰色）

#### Scenario: 正在称重状态
- **WHEN** 称重状态为 WaitingForStability
- **THEN** SHALL 显示 WeightStatus = "正在称重"
- **AND** SHALL 设置 WeightStatusColor = "#FBBF24"（黄色）

#### Scenario: 称重已结束状态
- **WHEN** 称重状态为 WeightStabilized 或 WaitingForDeparture
- **THEN** SHALL 显示 WeightStatus = "称重已结束"
- **AND** SHALL 设置 WeightStatusColor = "#4ADE80"（绿色）

### Requirement: 列表 Tab 筛选

WeighingSystemViewModel SHALL 支持按 Tab 切换筛选称重记录列表。

#### Scenario: 全部记录 Tab
- **WHEN** 用户选择"全部"Tab
- **THEN** SHALL 查询并显示所有 WeighingRecord（当前 WeighingMode = UrbanMode）

#### Scenario: 正常记录 Tab
- **WHEN** 用户选择"正常"Tab
- **THEN** SHALL 查询并显示 SyncStatus != Failed 的 WeighingRecord

#### Scenario: 异常记录 Tab
- **WHEN** 用户选择"异常"Tab
- **THEN** SHALL 查询并显示 SyncStatus = Failed 的 WeighingRecord

### Requirement: 列表搜索与分页

WeighingSystemViewModel SHALL 支持按车牌号和称重时间搜索，并支持分页查询。

#### Scenario: 按车牌号搜索
- **WHEN** 用户输入车牌号 "京A"
- **THEN** SHALL 查询 PlateNumber LIKE "%京A%" 的记录

#### Scenario: 按称重时间范围搜索
- **WHEN** 用户选择时间范围 2026-01-01 至 2026-01-31
- **THEN** SHALL 查询 CreationTime 在该范围内的记录

#### Scenario: 分页查询
- **WHEN** 查询结果超过 PageSize（默认 20）
- **THEN** SHALL 返回第一页数据
- **AND** SHALL 计算总页数

### Requirement: WeighingRecord 新增 SyncStatus 字段

WeighingRecord 实体 SHALL 新增 SyncStatus 属性，用于跟踪记录的同步状态。

#### Scenario: 新记录默认为 Pending
- **WHEN** 创建新的 WeighingRecord
- **THEN** SHALL 设置 SyncStatus = Pending

#### Scenario: SyncStatus 枚举值
- **WHEN** 系统使用 SyncStatus
- **THEN** SHALL 支持三个值：Pending（待上传）、Synced（已同步）、Failed（上传失败）

### Requirement: 启动时初始化 IAttendedWeighingService

MaterialClient.Urban App.axaml.cs SHALL 在应用启动后调用 `IAttendedWeighingService.StartAsync()` 启动称重管线。

#### Scenario: 应用启动后启动称重管线
- **WHEN** MaterialClient.Urban 应用启动完成，主窗口已显示
- **THEN** SHALL 解析 IAttendedWeighingService
- **AND** SHALL 调用 StartAsync() 启动称重管线
- **AND** SHALL 将 ViewModel 注入到 ILocalEventBus 订阅链路
