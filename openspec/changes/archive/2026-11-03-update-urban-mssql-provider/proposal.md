## Why

UrbanManagement 计划从 IIS + SQLite 迁到 Docker + SQL Server（蓝图 [`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/`](../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/00-调研总览.md)，Phase 1）。容器化之前要先让服务端能在 SQL Server 上运行，并能把现网 SQLite 数据完整、可校验地搬过去。SQLite 方言的迁移不能在 SQL Server 上执行；`decimal` 未设精度会静默截断重量；Windows 风格的附件相对路径（`\`）到 Linux 容器中会找不到文件。这几项都必须先在代码层解决。

## What Changes

- **BREAKING（部署侧）**：EF Core Provider 由 SQLite 换为 SQL Server。`ConnectionStrings:Default` 改为 SQL Server 连接串，生产连接串（含密码）通过环境变量或 `appsettings.secret.json` 提供，不进仓库。现网 IIS 实例在切换前继续运行旧版本。客户端接口与行为不变。
- 旧的 15 个 SQLite 迁移移出编译，改为单个 SQL Server 迁移基线（`InitialSqlServer`）。之后的迁移只为 SQL Server 生成。
- 模型修正：`UrbanWeighingRecord.TotalWeight`、`GovSyncData.GoodsWeight` 显式设定精度 `decimal(18,4)`。
- 附件路径与分隔符无关：`StoragePathResolver` 读取时兼容 `\` 和 `/`，写入时统一用 `/`。客户端上传接口和 `LocalPath` 语义不变。
- 新增一次性数据导入工具 `UrbanManagement.DataImport`，在停站后的 SQLite **副本**上运行：
  - `census`：只读普查（行数、小数位、超长列、大小写不敏感唯一冲突、附件路径分布、库体积）；
  - `import`：导入到**空**的 SQL Server 库，保留原主键和审计字段，包含软删除行，规范化 `AttachmentFile.LocalPath`；
  - 导入后自动校验，任何一项不一致即判失败。
- 决策记录：D3（MSSQL 版本）推迟到部署 change，本 change 的代码不依赖版本；D6 选择**接受回滚窗口内的新数据丢失**，不实现 MSSQL→SQLite 反向导出；D2（IIS ARR 反代）属于部署 change，本 change 不涉及。
- 非目标：Dockerfile / compose / 网关 / 健康检查 / Data Protection / 时区 / 角色拆分（后续 `add-urban-docker-deployment`、`refactor-urban-role-split`）；客户端（MaterialClient）任何改动；`EnableRetryOnFailure`。

## Capabilities

### New Capabilities

- `urban-sqlserver-persistence`：UrbanManagement 以 SQL Server 为唯一持久化 Provider，使用单一 SQL Server 迁移基线，重量 `decimal` 精度明确。
- `urban-sqlite-to-sqlserver-import`：一次性 SQLite → SQL Server 数据普查、导入与导入后校验。

### Modified Capabilities

- `abp-project-init`：Core 模块 EF Provider 由 SQLite 改为 SQL Server（移除 SQLite 要求）；解决方案新增数据导入工具项目。
- `attachment-file-storage`：存储的附件相对路径与分隔符无关（读取兼容 `\`，写入统一 `/`）。

## Impact

- **仓**：`repos/UrbanManagement`（Git Mode A，分支 `update-urban-mssql-provider` 自 `main`）。
- **代码**：`Directory.Packages.props`、`UrbanManagement.Core.csproj`、`UrbanManagementCoreModule`、`UrbanManagementDbContext`、`UrbanManagementDbContextFactory`、`EntityFrameworkCore/Migrations/`（整体替换）、`StoragePathResolver`、`appsettings.json`；新增 `tools/UrbanManagement.DataImport/`；`UrbanManagement.sln`；`tests/UrbanManagement.Core.Tests`。
- **依赖**：新增 `Volo.Abp.EntityFrameworkCore.SqlServer` / `Microsoft.EntityFrameworkCore.SqlServer` 10.0.1；`Microsoft.Data.Sqlite` 只由导入工具引用；`Microsoft.Data.SqlClient` 6.1.1 传递引入的 `System.Security.Cryptography.Pkcs` 9.0.4 有已知高危漏洞，Core 直接引用 10.0.14 覆盖。
- **客户端接口**：不变（REST、Legacy `/Api/Post`、SignalR、tus 端点均不受影响）。
- **运维**：本地开发与验证改用 SQL Server（LocalDB 或容器）；现网切换步骤与回滚见蓝图 `05`，执行属于部署 change。
- **已知文字漂移（不处理）**：若干现行 spec 正文用"SQLite"指代服务端库（如 `urban-signalr-hub-resilience`），语义上指"数据库"，本 change 不改其措辞。
