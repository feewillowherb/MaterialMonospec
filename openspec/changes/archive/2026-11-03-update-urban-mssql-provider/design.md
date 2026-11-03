## Context

- UrbanManagement（.NET 10 / ABP 10.0.1）目前用 `AbpEntityFrameworkCoreSqliteModule` + `UseSqlite()`，连接串 `Data Source=UrbanManagement.db`，启动时 `UrbanManagementAppModule.OnApplicationInitializationAsync` 调 `Database.MigrateAsync()`。
- `EntityFrameworkCore/Migrations/` 有 15 个 SQLite 方言迁移（其中 2 个为手写、无 Designer）。
- 实体表间无数据库外键（`no-database-fk`）；`GovProject` 软删除；`WorkSettingsEntity` 为 `int` 自增主键，`UrbanWeighingRecord` 等为 `long` 自增。
- 附件 `AttachmentFile.LocalPath` 存相对路径；在 Windows 上由 `Path.GetRelativePath` 生成，形如 `GDXS001\abc.jpg`。
- 蓝图（`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/04-数据库迁移SQLite到MSSQL.md`）已列出必须修的模型问题和导入/校验要求，本设计据此落地。
- 本机开发验证可用 SQL Server LocalDB（`MSSQLLocalDB`）；目标环境为 Docker 中的 `mcr.microsoft.com/mssql/server:2022-latest`（版本 D3 推迟）。

## Goals / Non-Goals

**Goals:**

- 服务端只依赖 SQL Server 运行，迁移基线可在空库上一次建好全部表与索引。
- 重量 `decimal` 不发生静默截断。
- 历史与新写入的附件路径在 Windows 与 Linux 上都能解析。
- 一次性导入工具：可重复执行的只读普查；对空库的原子导入；导入后机器可判定的校验结果。

**Non-Goals:**

- 容器化、网关、健康检查、Data Protection、时区、ForwardedHeaders（部署 change）。
- 角色拆分、SignalR backplane（`refactor-urban-role-split`）。
- MSSQL → SQLite 反向导出（D6：接受回滚窗口内数据丢失）。
- `EnableRetryOnFailure` / execution strategy。
- 改动任何客户端可见的接口与 DTO。

## Decisions

### 1. 单 Provider：只保留 SQL Server

`UrbanManagementCoreModule` 依赖改为 `AbpEntityFrameworkCoreSqlServerModule`，`AbpDbContextOptions` 改 `UseSqlServer()`。Core 不再引用任何 SQLite 包。

- 备选：按配置切换 SQLite / SQL Server 双 Provider。否决：两套迁移、两套方言差异要长期维护，回滚由"旧版本构建 + 原 SQLite 文件"承担即可。

### 2. 迁移基线：删除旧迁移，生成 `InitialSqlServer`

先完成模型修正，再删除 `Migrations/` 下全部 SQLite 迁移和快照，用 `dotnet ef migrations add InitialSqlServer` 生成单一基线。旧迁移保留在 Git 历史中。

- 备选：把旧迁移移到归档目录并 `<Compile Remove>`。否决：仓内留一套永远不会执行的代码，且导入工具直接读 SQLite 原始表，不需要旧迁移。
- 回滚使用的旧版本发布物自带旧迁移，不依赖本仓当前代码。

### 3. 数据库排序规则写进模型

`OnModelCreating` 调 `builder.UseCollation("Chinese_PRC_CI_AS")`。实测（LocalDB，服务器默认 `SQL_Latin1_General_CP1_CI_AS`）：EF 只在 `CREATE DATABASE` 时使用模型排序规则，生成的基线迁移不含 `AlterDatabase`，事先建好的空库会保留服务器默认值。因此另加一个手写迁移 `SetDatabaseCollation`（时间戳早于 `InitialSqlServer`），只执行 `AlterDatabase(collation)`。`ALTER DATABASE` 不能在事务中执行，单独成迁移可避免 EF 的"非事务操作混入迁移"警告。

- 备选：只在容器 `MSSQL_COLLATION` 设置。否决：LocalDB、手工建库等路径会漏掉。
- 影响：字符串比较由 SQLite 的区分大小写变为不区分。对唯一索引列，普查必须检测"仅大小写不同"的重复（见第 6 点）。

### 4. 重量精度 `decimal(18,4)`

`UrbanWeighingRecord.TotalWeight`、`GovSyncData.GoodsWeight` 使用 `HasPrecision(18, 4)`。测试库（5768 条）普查显示 `TotalWeight` 全为整数、最多 7 位整数位（量级与 kg 相符），`(18,4)` 的 14 位整数位与 4 位小数都留有余量。普查若发现源数据小数位 > 4 或整数位超出，判阻断，不允许导入。

### 5. 附件路径分隔符无关

新增静态类型 `StoredRelativePath`（`UrbanManagement.Core.Configuration`，纯逻辑，不注册 DI）：

- `ToPersisted(string relative)`：`\` → `/`，去掉开头的分隔符。
- `ToFileSystem(string stored)`：`\` 与 `/` 统一为 `Path.DirectorySeparatorChar`。

`StoragePathResolver.GetRelativeStoredPath` 返回值经 `ToPersisted`；`ResolveStoredPath` 在拼接前经 `ToFileSystem`。绝对路径分支行为不变。导入工具复用 `ToPersisted`。

- Windows 上 `Path.Combine` 本就接受 `/`，因此现网（IIS）读写行为不变。

### 6. 导入工具：独立控制台项目 `tools/UrbanManagement.DataImport`

引用 `UrbanManagement.Core`（复用 `UrbanManagementDbContext` 模型与迁移、`StoredRelativePath`），另引用 `Microsoft.Data.Sqlite`、`Microsoft.Data.SqlClient`（随 EF SqlServer 传递）。不启动 ABP 应用，用 `new UrbanManagementDbContext(options)` 获取模型和执行迁移（与设计时工厂相同方式）。

命令：

| 命令 | 行为 |
|------|------|
| `census --source <sqlite>` | 只读普查，输出 JSON 报告；存在阻断项时退出码 1 |
| `import --source <sqlite> [--legacy-storage-root <dir>] [--uploads-root <dir>]` | 普查 → 目标库执行迁移 → 空库检查 → 单事务导入 → 校验 → 报告 |

目标连接串只从环境变量 `UM_IMPORT_TARGET` 读取，避免密码出现在命令行和日志中。源库以 `Mode=ReadOnly` 打开。

要点：

- **表与列由 EF 模型驱动**：遍历模型实体的表名、列名、列的 Provider CLR 类型（含值转换器，如枚举 → `int`）。只导入模型中存在的表；源中多出的表（如 `__EFMigrationsHistory`）忽略。源中多出的列（SQLite 无法 DROP COLUMN 留下的旧列）记为警告；目标必填列在源中缺失则阻断。
- **值转换**：SQLite 原始值按目标 Provider 类型转换：`Guid`（TEXT / BLOB）、`DateTime`（TEXT，Invariant 解析）、`decimal`（TEXT / REAL / INTEGER）、`bool`（INTEGER）、整数族、枚举（底层整数）、`string`、`byte[]`。转换失败即阻断，报告表、主键与列。
- **写入**：`SqlBulkCopy`（`KeepIdentity | KeepNulls | TableLock`，按列名映射），全部表在同一个 `SqlTransaction` 中，任一表失败整体回滚，目标库保持为空。直接读写原始表，因此软删除行被包含，ABP 审计字段不被改写。
- **`AttachmentFile.LocalPath` 规范化**：先 `ToPersisted`；若为绝对路径且位于 `--legacy-storage-root` 之下，裁剪为相对路径；其余绝对路径保留原值并列入异常清单（不阻断）。
- **普查项**：每表行数；两个重量列最大小数位与最大整数位；所有带 `HasMaxLength` 的列实际最大长度；唯一索引含字符串列时按不区分大小写分组的重复；`LocalPath` 含 `\` / 绝对路径的数量及前缀；源文件大小与每表估算字节数（供 D3 评估 Express 10 GB 上限）。
- **校验**（导入提交后）：每表行数相等；重量列合计相等（源端按 `decimal` 在 C# 侧求和）；每表 `CreationTime` 最小/最大值相等（有该列时）；每表按主键随机抽样最多 50 行，逐列比较转换后的值；`--uploads-root` 给出时检查全部附件文件存在，缺失清单单独输出（不判失败）。
- **退出码**：0 通过；1 普查阻断或校验失败；2 参数错误或无法连接。

- 备选：作为 App 的子命令（`--import-sqlite`）。否决：App 启动链包含 Blazor、SignalR、后台任务与 Redis，一次性工具不应依赖它们；独立项目也便于后续作为 `migrator` 角色镜像的一部分。
- 备选：逐表 EF `AddRange`。否决：会经过 ABP 审计与软删除拦截，改写审计字段。

### 7. 连接串与设计时工厂

- `appsettings.json` 的 `Default` 改为本机开发用 LocalDB：`Server=(localdb)\MSSQLLocalDB;Database=UrbanManagement;Trusted_Connection=True;TrustServerCertificate=True`，不含密码。
- 生产（容器）通过环境变量 `ConnectionStrings__Default` 覆盖，必须含 `TrustServerCertificate=True`（自签证书）。
- 设计时工厂读取环境变量 `UM_DESIGNTIME_CONNECTION`，缺省同 LocalDB 连接串；生成迁移本身不需要连接数据库。

### 8. 启动迁移保持现状

`MigrateAsync` 在 SQL Server 上同样可用，本 change 不改启动流程；"仅 migrator 角色迁移"放到角色拆分 change。

## Risks / Trade-offs

- [`dotnet-ef` 全局工具为 9.0.10，项目为 EF 10] → 优先使用与 EF 10 匹配的工具版本（本地工具清单或 `dotnet dnx`）；生成的迁移在 LocalDB 上实际执行验证。
- [`AlterDatabase(collation)` 需要对库的独占访问，且不在事务内] → 只在空库首次迁移时执行，此时无其它连接；导入工具与应用不并发首次迁移（运行手册约定先跑导入）。若该迁移中途失败，删库重来即可（库为空）。
- [不区分大小写后唯一索引冲突] → 普查检测并阻断，由人工清理源副本后重跑。
- [LocalDB 与容器版 SQL Server 存在差异（版本、默认设置）] → 本 change 用 LocalDB 做开发验证；真实导入演练在部署 change 中针对 Docker MSSQL 进行，并作为 ICD 交付证据。
- [单事务导入在大库上占用日志空间] → 现网库体积预期很小（由普查给出）；若普查显示超出预期，再改为分表事务 + 失败清库。
- [`decimal(18,4)` 选择基于单位推断] → 普查数据是最终依据，超出即阻断，不会静默截断。

## Migration Plan

1. 本 change 合入后，现网 IIS 仍运行旧版本，不受影响。
2. 部署 change 中：停站 → 复制 SQLite 副本与 `Uploads/` → `census` → `import` → 启动新容器 → 客户端回归。
3. 回滚：恢复 IIS 站点（旧版本 + 原 SQLite 文件未被修改）；切换后写入 SQL Server 的新数据按 D6 接受丢失，窗口限切换当天。

## Open Questions

- D3（Express / Standard）：在部署 change 前依据普查的库体积决定，本 change 的代码不依赖该选择。
