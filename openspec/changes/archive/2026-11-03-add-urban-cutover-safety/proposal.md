## Why

Phase 2 栈已在 `5333` 验收通过（蓝图 `05` §5.1 / §5.2），切换 5233 前还缺两张安全网，都需要代码：

1. **数据库备份**：新栈的 MSSQL 没有任何备份；虚拟机磁盘或卷出问题即丢全部数据（蓝图 `06` 检查清单「MSSQL 备份任务配置并完成一次恢复演练」）。
2. **回滚数据（D6）**：切换后若回滚到 IIS，切换期间写入 MSSQL 的数据（新记录、同步状态变化）旧栈看不到；不带同步状态写回会导致 Gov Worker 重复上报（K13）。蓝图原计划「导入工具反向模式」，尚未实现。

D6 由 Agent 决策（用户授权自动决策，2026-11-03）：**不接受丢失，提供全量反向导出**。全量而非按 `CreationTime > 切换时间` 增量，因为切换前已有的记录在切换后也会改同步状态与审批状态，增量导出会漏掉这些更新。

## What Changes

- **导入工具 `export-sqlite` 命令**（`tools/UrbanManagement.DataImport`）：
  - 输入：`--source` 切换前 SQLite 副本（模板），`--output` 新文件（必须不存在，且不同于 `--source`）；SQL Server 连接串仍只取 `UM_IMPORT_TARGET`。
  - 用 SQLite 在线备份 API 复制模板（含 `-wal` 中的页），再在**一个事务内**把每张模型表整表替换为 SQL Server 的全部行；模板中模型之外的表与 `__EFMigrationsHistory` 原样保留。
  - 值按 EF Core SQLite 提供程序的存储格式写入（日期 `yyyy-MM-dd HH:mm:ss.FFFFFFF`、decimal 文本、bool 整数）；GUID 文本大小写**按模板逐列探测**（现网数据中 `ClientOnlineStatuses.ProId`、`ClientDeviceOnlineStatuses.ProId` 为小写，其余为大写）。
  - 模板缺模型表、或模板有无默认值的必填列而模型没有：阻断，不保留输出。
  - 校验：每表行数与逐行内容（读回后按主键比对）；**存储格式**：两边都有且语义相同的行，原始存储值必须逐字相同。
- **MSSQL 备份侧车** `mssql-backup`（compose，mssql 镜像，共用 `um-mssql` 卷，不发布端口）：
  - 每天 `UM_BACKUP_AT`（默认 02:30）完整备份 `CHECKSUM` + `RESTORE VERIFYONLY`，保留最新 `UM_BACKUP_KEEP`（默认 7）份，备份前记录用户表行数；
  - `verify-restore`：还原到临时库 `UrbanManagement_RestoreCheck`，`DBCC CHECKDB`，比对行数后删除；
  - `restore-replace` + 宿主脚本 `ops/mssql-restore.sh <file> --confirm`：停网关与角色 → 覆盖还原 → 启动（仅人工真实恢复时用）。
- **部署 Graph** `ops/deploy-urban-acceptance`：bundle 带 `ops/`，检查侧车运行与调度。
- **新 Graph** `ops/cutover-safety-drill`（probe）：备份 → 还原校验 → 回滚导出（一次性容器内，只留报告）。
- **非目标**：备份异地复制（需要宿主侧目标与凭据，见 design 待定项）；事务日志备份 / 时间点恢复（Express + SIMPLE 恢复模式足够当前规模）；IIS 用回滚文件真实启动演练（切换日按 runbook 执行）；MaterialClient 改动。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-sqlite-to-sqlserver-import`：新增「Rollback export to SQLite」。
- `urban-container-deployment`：新增「Scheduled database backup」。

## Impact

- `repos/UrbanManagement`：`tools/UrbanManagement.DataImport`（新命令与校验）、`deploy/docker/compose.yaml`、`deploy/docker/ops/*.sh`、`.env.example`、测试。
- monospec：`pipelines/graphs/ops/deploy-urban-acceptance`、新 `pipelines/graphs/ops/cutover-safety-drill`、蓝图 `00` D6、`05` §4 / §5.3、`06`。
- 虚拟机：多一个约 1 MiB 内存的侧车；备份占虚拟机根分区（当前每份约 16 MB）。
