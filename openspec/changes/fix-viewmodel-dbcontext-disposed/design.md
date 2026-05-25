## Context

`UrbanAttendedWeighingViewModel` 直接注入 `IRepository<WeighingRecord, long>` 用于分页查询称重记录。由于 ViewModel 注册为 `ITransientDependency`（实际随主窗口长存活），而 ABP 的 Repository 内部持有 Scoped 生命周期的 `MaterialClientDbContext`，当 DI 容器释放原始 Scope 后，DbContext 被 dispose，后续调用 `ReloadRecordsAsync()` 触发 `ObjectDisposedException`。

代码库中已存在 `IWeighingRecordService`（`ISingletonDependency`），使用 `IUnitOfWorkManager` 为每次操作创建独立 Scope。但该服务仅覆盖写操作（创建、照片保存、车牌重写），缺少 ViewModel 需要的分页查询能力。

现有参考模式：`StandardService` 使用 `[UnitOfWork]` 属性 + `PagedResultDto<T>` 返回类型实现分页查询。

```
当前架构（有问题）：
┌─────────────────────────────────────┐
│ UrbanAttendedWeighingViewModel      │
│  (ITransientDependency, 长存活)     │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ IRepository<WeighingRecord> │───────► Scoped DbContext (已 disposed!)
│  │  (构造函数注入, Scoped)     │    │
│  └─────────────────────────────┘    │
│                                     │
│  ReloadRecordsAsync() ─────────► ❌ ObjectDisposedException
└─────────────────────────────────────┘

修复后架构：
┌─────────────────────────────────────┐
│ UrbanAttendedWeighingViewModel      │
│  (ITransientDependency, 长存活)     │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ IWeighingRecordService      │───────► IUnitOfWorkManager.Begin()
│  │  (ISingletonDependency)     │    │       → 新 Scope → 新 DbContext
│  └─────────────────────────────┘    │       → CompleteAsync() → Dispose
│                                     │
│  ReloadRecordsAsync() ─────────► ✓ 每次查询使用新 DbContext
└─────────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**

- 消除 `ObjectDisposedException` 运行时异常
- ViewModel 不再持有超出生命周期的 DbContext 引用
- 数据库访问通过 Service 层按需创建 Scope，符合 AGENTS.md 架构约束
- 遵循代码库现有模式（`StandardService` 的 `[UnitOfWork]` + `PagedResultDto<T>`）

**Non-Goals:**

- 不重构其他 ViewModel 或 Service
- 不修改 `IWeighingRecordService` 现有的写操作方法
- 不修改数据库结构或 Entity 定义
- 不引入新的依赖包或框架

## Decisions

### Decision 1: 扩展现有 `IWeighingRecordService` 而非创建新 Service

**选择**: 在 `IWeighingRecordService` 接口中新增查询方法。

**备选方案**:
- A) 扩展 `IWeighingRecordService`（采用）
- B) 创建独立的 `IWeighingRecordQueryService`

**理由**: 查询的领域实体（WeighingRecord）与写操作完全一致，且 `WeighingRecordService` 已注入所需的 `IRepository<WeighingRecord, long>` 和 `IUnitOfWorkManager`。创建独立 Service 会引入不必要的类和文件，违反 "three similar lines is better than a premature abstraction" 原则。

### Decision 2: 使用 `[UnitOfWork]` 属性而非手动 `_unitOfWorkManager.Begin()`

**选择**: 新增的查询方法使用 `[UnitOfWork]` 属性修饰。

**备选方案**:
- A) `[UnitOfWork]` 属性（采用）
- B) 手动 `_unitOfWorkManager.Begin()` + `CompleteAsync()`

**理由**: `StandardService.GetPagedExportRowsAsync` 已验证 `[UnitOfWork]` 属性在查询场景中的正确性。属性方式更简洁，ABP 自动管理 Scope 生命周期。手动方式仅在读+写混合事务中需要，纯查询无需此复杂度。

### Decision 3: 使用 ABP 的 `PagedResultDto<WeighingRecord>` 作为返回类型

**选择**: 返回 `PagedResultDto<WeighingRecord>`。

**理由**: 代码库中 `StandardService` 已使用此类型，无需引入新类型。`PagedResultDto` 提供 `TotalCount` 和 `Items` 集合，正好满足 ViewModel 的分页需求。

### Decision 4: 使用方法参数而非 Filter DTO

**选择**: 方法签名使用独立参数（`int pageIndex, int pageSize, string? tabFilter, string? searchText, DateTime? startTime, DateTime? endTime`）。

**备选方案**:
- A) 独立参数（采用）
- B) 创建 `WeighingRecordFilter` DTO

**理由**: 查询条件简单（6 个参数），且仅此一个方法使用。创建 DTO 类会增加一个文件但只有一个消费者。`StandardExportFilter` 之所以用 DTO，是因为它有 7 个字段且被多处使用。此处参数数量在阈值内，不需要额外抽象。

### Decision 5: 查询方法限定为 UrbanMode

**选择**: 方法内部硬编码 `WeighingMode.UrbanMode` 过滤条件。

**理由**: 当前唯一调用者是 `UrbanAttendedWeighingViewModel`，仅查询 Urban 模式记录。若未来其他 ViewModel 需要分页查询，可新增方法或参数化 WeighingMode，但不在本次修复范围。

## Risks / Trade-offs

- **[风险] `WeighingRecordService` 接口膨胀** → 影响：每新增一个查询方法，所有实现者需更新。缓解：当前接口仅 4 个方法，新增 1 个可接受。若未来持续增长，再考虑读写分离。
- **[风险] `[UnitOfWork]` 属性需要 `virtual` 方法** → 影响：ABP 的 `[UnitOfWork]` 属性拦截器要求方法为 `virtual`。缓解：`StandardService.GetPagedExportRowsAsync` 已使用 `virtual` 模式，遵循此惯例即可。
- **[权衡] 方法参数较多（6 个）** → 缓解：对比 `StandardExportFilter` DTO 的 7 个字段，参数数量相当。若后续有第二个消费者，可重构为 DTO。
