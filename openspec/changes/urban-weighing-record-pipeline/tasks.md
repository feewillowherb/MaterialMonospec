## 1. 共享域层扩展（MaterialClient.Common）

- [ ] 1.1 新建 `MaterialClient.Common/Entities/Enums/SyncStatus.cs`：定义枚举（Pending、Synced、Failed）
- [ ] 1.2 修改 `MaterialClient.Common/Entities/WeighingRecord.cs`：新增 `SyncStatus` 属性（默认 Pending），配置 SQLite 列映射

## 2. AttendedWeighing 内部扩展 UrbanMode（MaterialClient.Common）

- [ ] 2.1 修改 `MaterialClient.Common/Services/AttendedWeighing/AttendedWeighingService.cs`：在 `ProcessStatusTransition` 中注入 `ISettingsService` 获取当前 `WeighingMode`，UrbanMode 分支中跳过 `RewriteAndResetCycleAsync` 对 `TryMatchEvent` 的触发
- [ ] 2.2 修改 `MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs`：在 `TryReWritePlateNumberAsync` 内部，当 `WeighingMode = UrbanMode (201)` 时跳过 `TryMatchEvent` 发布（不调用 `_localEventBus.PublishAsync(new TryMatchEvent(...))`）

## 3. MaterialClient.Urban ViewModel 绑定（复用已有管线事件）

- [ ] 3.1 修改 `MaterialClient.Urban/ViewModels/WeighingSystemViewModel.cs`：移除 mock 数据加载，通过 `ILocalEventBus.Subscribe<WeighingRecordCreatedEventData>` 刷新 WeighingRecords 集合
- [ ] 3.2 实现 WeightStatus 状态文案绑定：通过 `ILocalEventBus.Subscribe<StatusChangedEventData>` 更新文案和颜色
- [ ] 3.3 实现 CurrentWeight 实时绑定：通过 `IAttendedWeighingService` 暴露的重量流或 `ILocalEventBus` 事件更新显示
- [ ] 3.4 实现列表 Tab 筛选：全部/正常/异常，查询本地仓储过滤 SyncStatus
- [ ] 3.5 实现列表搜索：按车牌号模糊查询、按称重时间范围查询
- [ ] 3.6 实现列表分页：PageSize=20，查询本地仓储分页

## 4. MaterialClient.Urban 启动集成

- [ ] 4.1 修改 `MaterialClient.Urban/App.axaml.cs`：解析 `IAttendedWeighingService` 并在窗口显示后调用 `StartAsync()`

## 5. UrbanManagement 服务端实体与数据层

- [ ] 5.1 新建 `UrbanManagement.Core/Entities/UrbanWeighingRecord.cs`：定义实体（Id、ClientRecordId、PlateNumber、TotalWeight、WeighingTime、AddTime、SyncType、SnapImages），ClientRecordId 唯一索引
- [ ] 5.2 修改 `UrbanManagement.Core/EntityFrameworkCore/UrbanManagementDbContext.cs`：添加 DbSet<UrbanWeighingRecord>，配置表名 `Urban_WeighingRecord`，配置 ClientRecordId 唯一索引

## 6. UrbanManagement 服务端业务服务

- [ ] 6.1 新建 `UrbanManagement.Core/Services/IUrbanWeighingRecordAppService.cs`：定义接口（ReceiveAsync、GetPagedAsync）
- [ ] 6.2 新建 `UrbanManagement.Core/Services/UrbanWeighingRecordAppService.cs`：实现接收逻辑（ClientRecordId 去重、插入新记录）和分页查询逻辑

## 7. UrbanManagement API 端点

- [ ] 7.1 新建 `UrbanManagement.App/Controllers/UrbanWeighingRecordController.cs`：实现 POST /api/urban/weighing-records（接收称重记录）和 GET /api/urban/weighing-records（分页查询）
- [ ] 7.2 定义接收 DTO：UrbanWeighingRecordDto（ClientRecordId、PlateNumber、TotalWeight、WeighingTime、SyncType）

## 8. 集成验证

- [ ] 8.1 验证 MaterialClient 端到端流程：IAttendedWeighingService 启动 → 设备模拟器 → 重量稳定 → SQLite 记录 → UI 列表刷新 → UrbanMode 不触发 TryMatchEvent
- [ ] 8.2 验证 UrbanManagement 端：POST 接收记录 → SQLite 持久化 → GET 分页查询 → 重复记录幂等处理
