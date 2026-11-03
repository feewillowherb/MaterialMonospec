## Context

蓝图 `05` §3 切换 runbook 与 §4 回滚依赖两件尚不存在的东西：MSSQL 备份和「MSSQL → SQLite」反向导出。导入工具已有 `ModelCatalog`（从 `UrbanManagementDbContext` 设计时模型得到表、列、主键、提供程序类型）、`SqliteSource`（读 SQLite 并转换为 SQL Server 提供程序类型）与 `SqliteValueConverter`。

## Goals / Non-Goals

**Goals**：回滚时 IIS 拿到的 SQLite 与切换后的 MSSQL 内容一致、格式与旧数据一致；每日备份可还原且有演练证据。

**Non-Goals**：异地备份、时间点恢复、增量回滚、MaterialClient 改动。

## Decisions

### D-1 全量整表替换，而不是增量

切换前已有的行在切换后会被修改（同步状态、审批），按 `CreationTime` 增量会漏。全库当前约 1.6 万行、导出 7 秒，全量成本可忽略。整表 `DELETE` + `INSERT` 在一个事务内，失败不留半成品；连接 `ForeignKeys=false`，旧 schema 即使带引擎外键也不受表顺序影响。

### D-2 模板 = 切换前 SQLite 副本

schema、`__EFMigrationsHistory`、模型之外的表都来自 IIS 自己的库，旧二进制无需迁移即可打开。复制用 `SqliteConnection.BackupDatabase`，包含 `-wal` 中未检查点的页。输出必须是新文件，模板只读。

### D-3 存储格式以 Microsoft.Data.Sqlite 绑定器为准，GUID 大小写以数据为准

`SqliteValueConverter.ToSqlite` 产出与 EF Core SQLite 提供程序相同的文本（单测逐类型对比 `Microsoft.Data.Sqlite` 参数绑定的结果）。现网演练发现 `ClientOnlineStatuses.ProId` 与 `ClientDeviceOnlineStatuses.ProId` 存的是小写 GUID：`Plan` 对每个 GUID 列抽样模板中最多 100 个含字母的文本值，小写多于大写则该列写小写。校验 `storage-format` 对两边都有的行逐字比对原始值，防止格式漂移让 IIS 的等值查询失配。

### D-4 备份走 mssql 镜像侧车

侧车复用已拉取的 `mcr.microsoft.com/mssql/server:2022-latest`（自带 `sqlcmd`），入口替换为脚本，不启动 sqlservr；挂同一个 `um-mssql` 卷，`BACKUP TO DISK` 写到 `/var/opt/mssql/backup`（服务器与侧车看到同一路径），侧车负责轮转。密码只经 `SQLCMDPASSWORD` 环境变量，不进 argv。Express 不支持备份压缩，不使用 `COMPRESSION`。

### D-5 还原校验用临时库

`verify-restore` 用 `RESTORE FILELISTONLY` 取逻辑文件名，`MOVE` 到 `<db>_RestoreCheck`，`DBCC CHECKDB`，比对备份前记录的用户表行数，最后删除临时库。生产库全程只读。

## Risks / Trade-offs

- 备份与数据库在同一虚拟机磁盘：虚拟机整体损坏时备份一并丢失。→ 待定：异地复制目标（宿主专用共享或其他），不复用 `um-uploads`（该目录在 IIS 站点下）。
- 回滚文件中附件 `LocalPath` 已规范化为 `/` 分隔的相对路径：Windows 上 `Path.Combine` 接受 `/`；切换日用回滚文件启动 IIS 时在 runbook 中检查照片预览。
- 行数比对在备份前计数，备份期间若有写入可能误报 `rows-mismatch`；验收栈流量很低，生产日常备份只记日志不阻断。

## Open Questions（不阻塞本 change）

- 备份异地复制目标与保留策略。
- 生产切换后是否需要更频繁的备份（当前每日一次，RPO 24 小时）。
