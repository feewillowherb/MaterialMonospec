## 0. 分支（Mode A）

- [x] 0.1 `repos/UrbanManagement` 与 monospec 自 `main` 切 `add-urban-cutover-safety`

## 1. 回滚导出（UrbanManagement）

- [x] 1.1 `ImportOptions`：`export-sqlite` 命令、`--output`（必须不存在且不同于 `--source`）；`TargetConnection` 改名 `SqlServerConnection`
- [x] 1.2 `SqlServerSource.ReadAsync`：按模型读全部表
- [x] 1.3 `SqliteValueConverter.ToSqlite`：EF Core SQLite 存储格式；GUID 可选小写
- [x] 1.4 `SqliteTarget`：`CreateFromTemplate`（在线备份 API）、`Plan`（缺表 / 必填列阻断，GUID 列大小写探测）、`Write`（单事务整表替换，`ForeignKeys=false`）
- [x] 1.5 `ExportVerification`：读回逐行比对、`storage-format` 逐字比对
- [x] 1.6 测试：`ToSqlite` 与 `Microsoft.Data.Sqlite` 绑定器逐类型一致；往返；模板 → 输出整表替换、未知列默认值、小写 GUID 列、缺表阻断

## 2. 备份（UrbanManagement）

- [x] 2.1 `deploy/docker/ops/mssql-backup.sh`：`loop` / `once` / `verify-restore` / `restore-replace`
- [x] 2.2 `deploy/docker/ops/mssql-restore.sh`：`--confirm` 门槛，停网关与角色 → 还原 → 启动
- [x] 2.3 `compose.yaml` 增加 `mssql-backup`；`.env.example` 增加 `UM_BACKUP_AT`、`UM_BACKUP_KEEP`；`deploy/.gitattributes` 固定 `*.sh` 为 LF
- [x] 2.4 `dotnet build` 与 `dotnet test` 通过（223）

## 3. Graph（monospec）

- [x] 3.1 `ops/deploy-urban-acceptance`：bundle 带 `ops/`，安装到 `/opt/urbanmanagement/ops`；检查侧车运行与调度
- [x] 3.2 新建 `ops/cutover-safety-drill`（config、contract、pipeline、acceptance、脚本）

## 4. 部署与演练

- [x] 4.1 部署 run `2026-11-03T133826` `pass`（侧车 running，调度 02:30 / 7 份）
- [x] 4.2 演练 run `2026-11-03T134022` `pass`：备份 15.9 MB、还原校验 CHECKDB ok 行数 16474 = 16474；回滚导出 11 表 16474 行，33/33 检查通过（含 11 项 storage-format）
- [x] 4.3 回写蓝图 `00` D6、`05` §4 / §5.3、`06`
- [ ] 4.4 人工验收（P3，用户）
