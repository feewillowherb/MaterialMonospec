## 1. IWeighingRecordService 新增分页查询方法

- [x] 1.1 在 `IWeighingRecordService` 接口中新增 `GetPagedUrbanWeighingRecordsAsync` 方法签名，参数：`int pageIndex, int pageSize, string? tabFilter, string? searchText, DateTime? startTime, DateTime? endTime`，返回 `Task<PagedResultDto<WeighingRecord>>`
- [x] 1.2 在 `WeighingRecordService` 实现中添加 `GetPagedUrbanWeighingRecordsAsync` 方法，使用 `[UnitOfWork]` 和 `virtual` 修饰
- [x] 1.3 实现查询逻辑：从 `_weighingRecordRepository` 获取 IQueryable，Include UrbanExtension，按 WeighingMode=UrbanMode 过滤
- [x] 1.4 实现 tabFilter 过滤（"正常"排除 SyncStatus=Failed 和 null Extension，"异常"仅 SyncStatus=Failed）
- [x] 1.5 实现 searchText 车牌号模糊搜索（PlateNumber.Contains，空白字符串跳过）
- [x] 1.6 实现 startTime/endTime 时间范围过滤（AddDate >= / <=）
- [x] 1.7 实现分页计算（TotalCount + OrderByDescending AddDate + Skip/Take）并返回 `PagedResultDto<WeighingRecord>`

## 2. UrbanAttendedWeighingViewModel 迁移到 Service

- [x] 2.1 将构造函数中 `IRepository<WeighingRecord, long> weighingRecordRepository` 参数替换为 `IWeighingRecordService weighingRecordService`
- [x] 2.2 更新对应字段声明：移除 `_weighingRecordRepository`，新增 `_weighingRecordService`
- [x] 2.3 重写 `ReloadRecordsAsync` 方法：调用 `_weighingRecordService.GetPagedUrbanWeighingRecordsAsync`，从返回的 `PagedResultDto` 更新 `TotalCount`、`TotalPages`、`WeighingRecords`
- [x] 2.4 移除 ViewModel 文件中不再需要的 `using Volo.Abp.Domain.Repositories` 和 `using Microsoft.EntityFrameworkCore` 引用

## 3. 验证

- [x] 3.1 编译通过，无编译错误
- [ ] 3.2 运行应用，确认称重记录列表正常加载
- [ ] 3.3 验证标签过滤（全部/正常/异常）功能正常
- [ ] 3.4 验证车牌号搜索功能正常
- [ ] 3.5 验证时间范围过滤功能正常
- [ ] 3.6 验证分页翻页功能正常
- [ ] 3.7 验证不再出现 ObjectDisposedException
