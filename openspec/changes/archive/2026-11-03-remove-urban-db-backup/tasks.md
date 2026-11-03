## 0. 分支（Mode A）

- [x] 0.1 `repos/UrbanManagement` 与 monospec 自 `main` 切 `remove-urban-db-backup`

## 1. UrbanManagement

- [x] 1.1 `compose.yaml` 移除 `mssql-backup`；删除 `deploy/docker/ops/*.sh`；`.env.example` 移除备份变量

## 2. Graph（monospec）

- [x] 2.1 `ops/deploy-urban-acceptance`：bundle 不带 `ops/`，移除侧车检查
- [x] 2.2 `ops/cutover-safety-drill`：只保留回滚导出

## 3. 部署与清理

- [x] 3.1 部署 Graph `pass`，服务列表无 `mssql-backup`（run `2026-11-03T135051`）
- [x] 3.2 删除虚拟机 `um-mssql` 卷中的演练备份文件与 `/opt/urbanmanagement/ops`
- [x] 3.3 演练 Graph `pass`（回滚导出，run `2026-11-03T135313`，33/33）
- [x] 3.4 蓝图 `00` D15、`05` §5.3、`06` 回写
