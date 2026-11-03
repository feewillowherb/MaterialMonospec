## 0. 分支（Git Mode A）

- [x] 0.1 `repos/UrbanManagement`：自 `main` 创建并切换分支 `update-urban-mssql-provider`

## 1. Provider 切换

- [x] 1.1 `Directory.Packages.props` 新增 `Volo.Abp.EntityFrameworkCore.SqlServer`、`Microsoft.EntityFrameworkCore.SqlServer`（10.0.1）与 `Microsoft.Data.Sqlite`；移除 Core 不再需要的 SQLite EF 包版本项
- [x] 1.2 `UrbanManagement.Core.csproj` 改引用 SqlServer 包，去掉 SQLite 包
- [x] 1.3 `UrbanManagementCoreModule`：`AbpEntityFrameworkCoreSqlServerModule` + `UseSqlServer()`
- [x] 1.4 `UrbanManagementDbContextFactory`：`UseSqlServer`，连接串取 `UM_DESIGNTIME_CONNECTION`，缺省 LocalDB
- [x] 1.5 `appsettings.json` 的 `ConnectionStrings:Default` 改为 LocalDB 开发连接串（不含密码）

## 2. 模型修正与迁移基线

- [x] 2.1 `OnModelCreating`：`UseCollation("Chinese_PRC_CI_AS")`；`TotalWeight`、`GoodsWeight` `HasPrecision(18, 4)`
- [x] 2.2 删除 `EntityFrameworkCore/Migrations/` 下全部 SQLite 迁移与快照
- [x] 2.3 生成 `InitialSqlServer` 基线迁移；手写 `SetDatabaseCollation`（早于基线，仅 `AlterDatabase(collation)`）
- [x] 2.4 在 LocalDB 空库上执行迁移，确认表、索引、`decimal(18,4)`、库排序规则（新建库与预建空库两种情况）；确认无 pending model changes

## 3. 附件路径分隔符无关

- [x] 3.1 新增静态类型 `StoredRelativePath`（`ToPersisted` / `ToFileSystem`），不注册 DI
- [x] 3.2 `StoragePathResolver.GetRelativeStoredPath` 输出 `/`；`ResolveStoredPath` 兼容 `\` 与 `/`
- [x] 3.3 `tests/UrbanManagement.Core.Tests`：`StoredRelativePath` 与 `StoragePathResolver` 的反斜杠 / 正斜杠用例

## 4. 数据导入工具

- [x] 4.1 新建 `tools/UrbanManagement.DataImport` 控制台项目（引用 Core、`Microsoft.Data.Sqlite`），加入 `UrbanManagement.sln`
- [x] 4.2 EF 模型驱动的表/列元数据与 SQLite 值转换（Guid、DateTime、decimal、bool、整数、枚举、string、byte[]）
- [x] 4.3 `census` 命令：行数、小数位/整数位、超长列、大小写不敏感唯一冲突、`LocalPath` 分布、文件大小；JSON 报告；阻断项退出码 1
- [x] 4.4 `import` 命令：先普查 → 目标迁移 → 空库检查 → 单事务 `SqlBulkCopy`（KeepIdentity / KeepNulls / TableLock）→ `LocalPath` 规范化与异常清单
- [x] 4.5 导入后校验：行数、重量合计、`CreationTime` 边界、主键抽样逐列比对、可选附件存在性检查；报告与退出码
- [x] 4.6 本地演练：复制开发 SQLite 库 → `census` → `import` 到 LocalDB 新库 → 校验通过；再次 `import` 被空库检查拒绝

## 5. 验证与收尾

- [x] 5.1 `dotnet build UrbanManagement.sln` 无错误；`dotnet test` 通过
- [x] 5.2 应用以 LocalDB 启动：迁移成功、管理端首页可打开（客户端接口未改动，冒烟即可）
- [x] 5.3 子仓提交到 `update-urban-mssql-provider` 分支（`e8d81d3`，仅本地；按用户指示再 squash 合入 `main`）
