## ADDED Requirements

### Requirement: ABP 标准审计接口实现

UrbanManagement 实体 SHALL 实现 ABP 标准审计接口，审计字段（`CreationTime`、`CreatorUserId`、`LastModificationTime`、`LastModifierUserId`、`IsDeleted` 等）由框架（ABP UnitOfWork / EF Core SaveChanges 拦截器）自动填充，SHALL NOT 在领域方法或应用服务中手动赋值。适用实体：`GovProject`、`GovSyncData`、`GovLog`、`UrbanWeighingRecord`、`UrbanWeighingExtension`。

#### Scenario: 实体声明创建审计接口

- **WHEN** 实体需要记录创建时间
- **THEN** 实体 SHALL 实现 `IHasCreationTime`（或更完整的 `CreationAuditedEntity`/`FullAuditedEntity`/`*AggregateRoot` 基类，按是否需要用户上下文与软删除择优）
- **AND** `CreationTime` SHALL 在插入时由框架自动填充，SHALL NOT 由代码手动赋值

#### Scenario: UrbanWeighingRecord 仅实现 IHasCreationTime

- **WHEN** 处理 `UrbanWeighingRecord`（由 MaterialClient 经 API 推送，无用户认证上下文）
- **THEN** `UrbanWeighingRecord` SHALL 仅实现 `IHasCreationTime`
- **AND** MUST NOT 实现 `ICreationAudited`（`CreatorUserId` 无法自动填充）
- **AND** 数据来源项目 SHALL 通过已有 `ProId` 字段记录，MUST NOT 复用审计字段表达数据来源

#### Scenario: 移除手动审计赋值

- **WHEN** 改造涉及领域方法或应用服务
- **THEN** 代码中形如 `entity.AddTime = DateTime.Now`、`entity.CreationTime = ...`、`entity.CreatorUserId = ...`、`entity.LastModificationTime = ...` 的手动赋值 SHALL 被移除
- **AND** `UrbanWeighingRecord.ReceiveAsync` 中手动设置 `AddTime = DateTime.Now` 的逻辑 SHALL 移除，改由 `IHasCreationTime` 自动填充（语义等价于「服务端入库时间」）

### Requirement: AddTime → CreationTime 列标准化迁移

将非标准列 `AddTime` 标准化为 ABP 标准列 `CreationTime`，SHALL 通过 EF Core 列映射 + 数据迁移完成，确保历史数据不丢失。

#### Scenario: 列重命名迁移

- **WHEN** 实体属性由 `AddTime` 改为 `CreationTime`
- **THEN** SHALL 新增 Migration 执行列重命名或 `UPDATE SET CreationTime = AddTime WHERE CreationTime IS NULL` 回填
- **AND** EF Core 映射 SHALL 保证历史 `AddTime` 数据完整迁移至 `CreationTime`
- **AND** 迁移后旧 `AddTime` 列（如有）SHALL 在后续版本移除

#### Scenario: 列名映射过渡方案

- **WHEN** 暂不执行列重命名（过渡期）
- **THEN** MAY 使用 `builder.Property(e => e.CreationTime).HasColumnName("AddTime")` 将标准属性映射到旧列名
- **AND** 该过渡方案 SHALL 在后续版本收敛为标准列名

### Requirement: MaterialClient 自定义 SaveChangesInterceptor

MaterialClient（非 ABP 宿主，SQLite + EF Core）SHALL 注册自定义 `SaveChangesInterceptor`，在 `SavingChangesAsync` 时自动填充审计字段。

#### Scenario: 新增实体自动填充创建时间

- **WHEN** `EntityState == Added` 的实体被保存
- **THEN** 拦截器 SHALL 将 `CreationTime`（或 `CreatedAt`）设为当前时间
- **AND** SHALL NOT 依赖 ABP 框架

#### Scenario: 修改实体自动填充修改时间

- **WHEN** `EntityState == Modified` 的实体被保存
- **THEN** 拦截器 SHALL 将 `LastModificationTime`（或 `UpdatedAt`）设为当前时间

### Requirement: 政府出站 DTO 独立映射

政府出站数据（`GovSyncWorker`）SHALL 通过手动映射或 AutoMapper Profile 显式配置出站字段，MUST NOT 直接引用实体审计属性，确保实体属性重命名不影响政府协议字段名（如 `addTime`）。

#### Scenario: 出站字段名保持政府协议

- **WHEN** 实体 `AddTime` 重命名为 `CreationTime`
- **THEN** 政府出站 DTO 字段名 SHALL 保持协议要求的 `addTime` 不变
- **AND** 出站映射 SHALL 显式从 `CreationTime` 取值写入 DTO 的 `addTime` 字段
- **AND** MUST NOT 因实体属性重命名导致政府对接字段变化
