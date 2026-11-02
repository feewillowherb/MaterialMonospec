# 04 数据库迁移：SQLite → MSSQL（Docker）

## 1. Provider 切换

| 项 | 现状 | 目标 |
|----|------|------|
| NuGet | `Volo.Abp.EntityFrameworkCore.Sqlite`、`Microsoft.EntityFrameworkCore.Sqlite` | `Volo.Abp.EntityFrameworkCore.SqlServer`、`Microsoft.EntityFrameworkCore.SqlServer`（10.0.x，与 ABP 10.0.1 对齐）；SQLite 包只保留给数据导入工具 |
| 模块依赖 | `AbpEntityFrameworkCoreSqliteModule` | `AbpEntityFrameworkCoreSqlServerModule` |
| `AbpDbContextOptions` | `options.UseSqlite()` | `options.UseSqlServer()` |
| 设计时工厂 | `UseSqlite("Data Source=:memory:")` | `UseSqlServer(<本地开发连接串>)` |
| 连接串 | `Data Source=UrbanManagement.db` | `Server=mssql,1433;Database=UrbanManagement;User Id=um_app;Password=…;TrustServerCertificate=True` |

`Microsoft.Data.SqlClient` 默认 `Encrypt=True`，容器内自签证书必须加 `TrustServerCertificate=True`，否则启动即连接失败。

暂不开启 `EnableRetryOnFailure`：它与 ABP 显式事务（`[UnitOfWork(IsTransactional = true)]`）同时使用需要改为 execution strategy 包裹，属于额外改造。同机容器网络抖动概率低，先不引入。

## 2. 迁移基线重建

15 个现有迁移是 SQLite 方言（`TEXT`/`INTEGER` 类型、SQLite 的表重建式改列），**不能**在 SQL Server 上执行。

做法：

1. 先修模型（§3），再基于当前模型为 SQL Server 生成**单个新基线迁移**（如 `20261102000000_InitialSqlServer`）。
2. 旧 SQLite 迁移目录整体移出主项目编译（移入数据导入工具或归档目录），避免两套迁移同时被 EF 发现。
3. 之后所有新迁移都只为 SQL Server 生成。
4. 本地开发也改用 MSSQL 容器（`docker run mcr.microsoft.com/mssql/server:2022-latest`），不再维护 SQLite 双 Provider。

## 3. 生成基线前必须修的模型问题

| 问题 | 位置 | SQL Server 后果 | 处理 |
|------|------|-----------------|------|
| `decimal` 未设精度 | `UrbanWeighingRecord.TotalWeight`、`GovSyncData.GoodsWeight` | 默认 `decimal(18,2)`，超过 2 位小数**静默截断** | 先统计 SQLite 中实际最大小数位（§4.1），再 `HasPrecision(18, N)`；建议 N ≥ 3 |
| `HasMaxLength` 在 SQLite 不生效 | `GovSyncData.SnapImages`(2000)、`ClientDeviceOnlineStatus.AdditionalData`(2000)、`AttachmentFile.FileName`(200)、`AnomalyReason`(32) 等 | 存量超长数据导入时报 `String or binary data would be truncated` | 导入前做长度普查（§4.1）；超长列要么放宽长度，要么记录为数据问题 |
| 软删除过滤 | `GovProject : IHasDeletionTime`（ABP 中继承 `ISoftDelete`） | 用 ABP 上下文读取源库会**漏掉已删除项目** | 导入工具禁用 `ISoftDelete` 过滤或 `IgnoreQueryFilters()` |
| `int` 自增主键 | `WorkSettingsEntity` | 保留原 Id 需 `IDENTITY_INSERT` | 导入该表时开启 |
| 未入 DbContext 的实体 | `DeviceStatusLog`（`AuditedEntity<long>`，无 `DbSet`） | 无表 | 保持现状，不迁移 |

## 4. 数据导入（一次性）

### 4.1 导入前普查（只读，对 SQLite 副本执行）

- 每张表行数。
- `TotalWeight`、`GoodsWeight` 的最大小数位与最大值。
- 所有设置了 `HasMaxLength` 的列的实际最大长度。
- `AttachmentFile.LocalPath`：含 `\` 的行数、以盘符开头（绝对路径）的行数及前缀分布。
- 库文件大小（用于 D3：Express 单库 10 GB 上限），重点看 `LegacyWeighingRejectStagings`（Base64 不限长）。

### 4.2 导入工具

建议形态：UrbanManagement 仓新增控制台工具（或 `Migrator` 角色的子命令 `--import-sqlite <path>`）。

| 步骤 | 说明 |
|------|------|
| 1 | 目标库已由 `InitialSqlServer` 建好且**为空**；非空则拒绝执行（防止重复导入） |
| 2 | 源：只读打开 SQLite **副本**（停站后复制的那份），禁用软删除过滤 |
| 3 | 逐表批量写入（`SqlBulkCopy` 或 1000 行/批的 EF），**保留原主键与审计字段**；绕开 ABP 审计拦截，避免 `CreationTime`/`ConcurrencyStamp` 被改写（用不继承 `AbpDbContext` 的普通上下文或 `SqlBulkCopy`） |
| 4 | 因为没有外键（`no-database-fk`），表顺序不受约束 |
| 5 | `AttachmentFile.LocalPath` 在导入时规范化（§5） |
| 6 | 输出校验报告（§4.3），任何一项不一致即视为失败 |

### 4.3 导入后校验

| 校验 | 通过标准 |
|------|----------|
| 行数 | 每表源 = 目标 |
| 金额/重量 | `SUM(TotalWeight)`、`SUM(GoodsWeight)` 源 = 目标 |
| 时间边界 | 每表 `MIN/MAX(CreationTime)` 一致 |
| 主键抽样 | 随机抽样 Id 在目标存在且字段逐一相等（含 `ExtraProperties` JSON） |
| 附件可达 | 对全部 `AttachmentFile` 按新路径检查文件存在；缺失清单单独输出 |
| 应用自检 | 新栈启动后管理端能打开称重记录、照片预览、审批历史（`EditHistory`） |

## 5. 附件路径规范化

Windows 上 `Path.GetRelativePath` 生成的 `LocalPath` 形如 `GDXS20250415002\abc.jpg`。在 Linux 容器中 `\` 不是目录分隔符，`Path.Combine` 后会去找一个名字里带反斜杠的文件 → 历史照片全部 404。

双保险：

1. **数据层**：导入时把 `\` 统一替换为 `/`；以旧 `FilesPhysicalPath` 绝对根开头的路径裁剪为相对路径；其余绝对路径列入异常清单人工处理。
2. **代码层**：`StoragePathResolver.ResolveStoredPath` 读取时把 `\` 规范为 `Path.DirectorySeparatorChar`；`GetRelativeStoredPath` 写入时统一输出 `/`。这样即便漏网的旧数据也能读到。

附件文件本身：停站后把 `Uploads\`（含 `_tus` 可不拷）完整复制到 `um-uploads` 卷；`ClientLogs\` 视需要复制到 `um-clientlogs` 卷。Linux 文件系统大小写敏感，复制后按 §4.3 全量核对一次存在性。

## 6. SQLite 与 SQL Server 语义差异

| 差异 | 影响范围 | 结论 |
|------|----------|------|
| `string.Contains` 翻译：SQLite 用 `instr`（区分大小写）；SQL Server 用 `LIKE` + 库排序规则 | 管理端搜索（车牌、项目名、接入码） | 选 `Chinese_PRC_CI_AS` 后变为不区分大小写，属于体验改善；客户端接口不受影响 |
| 排序规则 | 中文排序、比较 | 库级 `Chinese_PRC_CI_AS`；EF 字符串默认 `nvarchar`，中文无乱码风险 |
| `uniqueidentifier` 排序与 Guid 字节序不同 | 若有按 `Id` 排序分页 | 当前未发现 `OrderBy(x => x.Id)`；分页均按时间排序（`INFERRED`，实现时复查） |
| 并发 | SQLite 单写者 → SQL Server 行级锁 | 吞吐提升；`ClientRecordId` 唯一索引继续保证幂等 |
| 可空唯一索引 | `ClientRecordId` 等 | EF SqlServer 对可空列唯一索引自动加 `IS NOT NULL` 过滤，与 SQLite 行为一致 |
| `DateTime` | `datetime2(7)` 保留到 100ns | 无损；`Kind` 本就不持久化 |
| 时区 | `GETDATE()` 等服务端函数 | 未使用；仍给 mssql 容器设 `TZ=Asia/Shanghai` 以便运维排查 |

## 7. 备份与运维

| 项 | 做法 |
|----|------|
| 全量备份 | 宿主"任务计划程序"定时执行 `docker exec mssql /opt/mssql-tools18/bin/sqlcmd … -Q "BACKUP DATABASE UrbanManagement TO DISK='/var/opt/mssql/backup/um_YYYYMMDD.bak' WITH COMPRESSION"`（Express 不支持 `COMPRESSION`，去掉该项） |
| 备份落盘 | 单独的 `um-mssql-backup` 卷或宿主目录，再同步到异机 |
| 恢复演练 | 切换前至少在测试环境完整恢复一次 |
| 附件备份 | `um-uploads` 卷按日增量（robocopy / rsync） |
| 账号 | `sa` 只用于运维；应用 `um_app` 最小权限；migrator 才有 DDL 权限 |
