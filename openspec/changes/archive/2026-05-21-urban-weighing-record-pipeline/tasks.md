## 1. 共享域层扩展（MaterialClient.Common）

- [x] 1.1 新建 `MaterialClient.Common/Entities/Enums/SyncStatus.cs`：定义枚举（Pending、Synced、Failed）
- [x] 1.2 修改 `MaterialClient.Common/Entities/WeighingRecord.cs`：新增 `SyncStatus` 属性（默认 Pending），配置 SQLite 列映射

## 2. 称重管线扩展点（策略接口 + Urban 实现）

- [x] 2.1 定义 `IWeighingPipelineStrategy`（或利用已有接口扩展）：声明跳过 waybill 匹对、TryMatchEvent 发布等扩展点方法
- [x] 2.2 新建 `MaterialClient.Urban/Services/UrbanWeighingPipelineStrategy.cs`：实现 `IWeighingPipelineStrategy`，UrbanMode 下跳过 `TryMatchEvent` 和 waybill 匹对逻辑
- [x] 2.3 新建 `MaterialClient.Urban/Services/UrbanWeighingService.cs`（或等价）：保证 `WeighingMode = UrbanMode`、`ProductCode = 5030` 的协调服务
- [x] 2.4 修改 `MaterialClient.Common/Services/AttendedWeighing/AttendedWeighingService.cs`：注入 `IWeighingPipelineStrategy`；在 `ProcessStatusTransition` 扩展点调用策略；默认实现兼容现有有人值守行为
- [x] 2.5 修改 `MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs`：在 `TryReWritePlateNumberAsync` 扩展点调用策略或 `WeighingMode == UrbanMode` 守卫，UrbanMode 跳过 `TryMatchEvent` 发布；保持默认行为兼容

## 3. MaterialClient.Urban ViewModel 绑定（复用已有管线事件）

- [x] 3.1 修改 `MaterialClient.Urban/ViewModels/WeighingSystemViewModel.cs`：移除 mock 数据加载，通过 `ILocalEventBus.Subscribe<WeighingRecordCreatedEventData>` 刷新 WeighingRecords 集合
- [x] 3.2 实现 WeightStatus 状态文案绑定：通过 `ILocalEventBus.Subscribe<StatusChangedEventData>` 更新文案和颜色
- [x] 3.3 实现 CurrentWeight 实时绑定：通过 `IAttendedWeighingService` 暴露的重量流或 `ILocalEventBus` 事件更新显示
- [x] 3.4 实现列表 Tab 筛选：全部/正常/异常，查询本地仓储过滤 SyncStatus
- [x] 3.5 实现列表搜索：按车牌号模糊查询、按称重时间范围查询
- [x] 3.6 实现列表分页：PageSize=20，查询本地仓储分页

## 4. MaterialClient.Urban 启动集成

- [x] 4.1 修改 `MaterialClient.Urban/App.axaml.cs`：注册 `IWeighingPipelineStrategy` → `UrbanWeighingPipelineStrategy`；解析 `IAttendedWeighingService` 并在窗口显示后调用 `StartAsync()`

## 5. UrbanManagement 服务端实体与数据层

- [x] 5.1 新建 `UrbanManagement.Core/Entities/UrbanWeighingRecord.cs`：定义实体（OQ-4：以 MaterialClient 本地 `WeighingRecord` 为蓝本，同构或子集 + 服务端元数据如 `ReceivedAt`、`DeviceId`），`ClientRecordId` 唯一索引
- [x] 5.2 修改 `UrbanManagement.Core/EntityFrameworkCore/UrbanManagementDbContext.cs`：添加 DbSet<UrbanWeighingRecord>，配置表名 `Urban_WeighingRecord`，配置 ClientRecordId 唯一索引

## 6. UrbanManagement 服务端业务服务

- [x] 6.1 新建 `UrbanManagement.Core/Services/IUrbanWeighingRecordAppService.cs`：定义接口（ReceiveAsync、GetPagedAsync）
- [x] 6.2 新建 `UrbanManagement.Core/Services/UrbanWeighingRecordAppService.cs`：实现接收逻辑（ClientRecordId 去重、插入新记录）和分页查询逻辑

## 7. UrbanManagement API 端点

- [x] 7.1 新建 `UrbanManagement.App/Controllers/UrbanWeighingRecordController.cs`：实现 POST /api/urban/weighing-records（接收称重记录）和 GET /api/urban/weighing-records（分页查询）
- [x] 7.2 定义接收 DTO：UrbanWeighingRecordDto（ClientRecordId、PlateNumber、TotalWeight、WeighingTime、DeviceId 等，字段集与 MaterialClient `WeighingRecord` 上传子集对齐）

## 8. 集成验证

- [x] 8.1 验证 MaterialClient 端到端流程：IAttendedWeighingService 启动 → 设备模拟器 → 重量稳定 → SQLite 记录 → UI 列表刷新 → UrbanWeighingPipelineStrategy 正确跳过 TryMatchEvent
- [x] 8.2 验证 Common 层回归：有人值守模式行为不受策略注入影响，现有回归测试通过
- [x] 8.3 验证 UrbanManagement 端：POST 接收记录 → SQLite 持久化 → GET 分页查询 → 重复记录幂等处理
