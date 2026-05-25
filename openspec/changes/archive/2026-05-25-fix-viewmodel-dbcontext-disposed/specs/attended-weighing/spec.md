## ADDED Requirements

### Requirement: WeighingRecordService 分页查询 Urban 称重记录

IWeighingRecordService SHALL 提供 `GetPagedUrbanWeighingRecordsAsync` 方法，支持按标签过滤、车牌号搜索、时间范围过滤的分页查询。方法 MUST 使用 `[UnitOfWork]` 属性修饰以确保每次查询在独立 Scope 中执行，避免 DbContext 生命周期问题。

#### Scenario: 无过滤条件查询全部 Urban 记录
- **WHEN** 调用 `GetPagedUrbanWeighingRecordsAsync(pageIndex=1, pageSize=20, tabFilter=null, searchText=null, startTime=null, endTime=null)`
- **THEN** SHALL 返回 WeighingMode=UrbanMode 的所有 WeighingRecord 分页结果
- **AND** SHALL 按AddDate降序排列
- **AND** SHALL 包含 UrbanExtension 导航属性（Include）
- **AND** TotalCount SHALL 反映符合条件的总记录数
- **AND** Items SHALL 为第1页的20条记录

#### Scenario: 按标签过滤正常记录
- **WHEN** 调用 `GetPagedUrbanWeighingRecordsAsync` 且 `tabFilter="正常"`
- **THEN** SHALL 仅返回 UrbanExtension.SyncStatus 不等于 Failed 的记录
- **AND** SHALL 排除 UrbanExtension 为 null 的记录

#### Scenario: 按标签过滤异常记录
- **WHEN** 调用 `GetPagedUrbanWeighingRecordsAsync` 且 `tabFilter="异常"`
- **THEN** SHALL 仅返回 UrbanExtension.SyncStatus 等于 Failed 的记录
- **AND** SHALL 排除 UrbanExtension 为 null 的记录

#### Scenario: 按车牌号模糊搜索
- **WHEN** 调用 `GetPagedUrbanWeighingRecordsAsync` 且 `searchText="京A"`
- **THEN** SHALL 仅返回 PlateNumber 包含 "京A" 的记录
- **AND** SHALL 忽略 searchText 为空白字符串的情况

#### Scenario: 按时间范围过滤
- **WHEN** 调用 `GetPagedUrbanWeighingRecordsAsync` 且 `startTime=2026-01-01`，`endTime=2026-01-31`
- **THEN** SHALL 仅返回 AddDate >= 2026-01-01 且 AddDate <= 2026-01-31 的记录

#### Scenario: 分页计算
- **WHEN** 符合条件的总记录数为 50，`pageSize=20`，`pageIndex=2`
- **THEN** TotalCount SHALL 为 50
- **AND** Items SHALL 包含第 21-40 条记录（按 AddDate 降序）

#### Scenario: 空结果集
- **WHEN** 无符合条件的记录
- **THEN** TotalCount SHALL 为 0
- **AND** Items SHALL 为空集合
- **AND** MUST NOT 抛出异常

#### Scenario: UnitOfWork 独立 Scope
- **WHEN** 多次连续调用 `GetPagedUrbanWeighingRecordsAsync`
- **THEN** 每次调用 SHALL 使用独立的 DbContext 实例
- **AND** 前一次调用的 DbContext SHALL 在方法返回后被释放
- **AND** MUST NOT 抛出 ObjectDisposedException
