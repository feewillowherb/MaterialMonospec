## Why

D15（2026-11-03，用户）：新栈不需要数据库备份，停用每日备份。`add-urban-cutover-safety` 加入的 `mssql-backup` 侧车与还原脚本因此不再需要。

## What Changes

- **移除** compose 中的 `mssql-backup` 服务、`deploy/docker/ops/mssql-backup.sh` 与 `mssql-restore.sh`、`.env.example` 中的 `UM_BACKUP_AT` / `UM_BACKUP_KEEP`。
- 部署 Graph `ops/deploy-urban-acceptance`：bundle 不再带 `ops/`，不再检查备份侧车；`up -d --remove-orphans` 移除虚拟机上已有的侧车容器。
- 演练 Graph `ops/cutover-safety-drill`：只保留回滚导出（`export-sqlite`）。
- 虚拟机上删除演练留下的备份文件（`um-mssql` 卷 `/var/opt/mssql/backup`）。
- **保留**：导入工具 `export-sqlite`（D6 回滚导出）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-container-deployment`：移除「Scheduled database backup」。

## Impact

- `repos/UrbanManagement`：`deploy/docker/compose.yaml`、`.env.example`、`deploy/docker/ops/`（删除）。
- monospec：两个 ops Graph、蓝图 `00` D15、`05` §5.3、`06`。
