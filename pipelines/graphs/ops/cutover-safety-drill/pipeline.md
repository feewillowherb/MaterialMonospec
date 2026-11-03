# ops / cutover-safety-drill

切换安全网演练：证明新栈的数据库**能备份、备份能还原**，以及切换后若要回滚到 IIS，**能把 SQL Server 的全部数据导回 SQLite**（蓝图 D6）。

## 做什么

1. `mssql-backup` 侧车立即做一次完整备份（`CHECKSUM` + `RESTORE VERIFYONLY`），备份前记录用户表总行数。
2. 把这份备份还原成临时库 `UrbanManagement_RestoreCheck`，`DBCC CHECKDB`，比对行数，然后删除临时库。
3. 回滚导出：取 `/opt/urbanmanagement/import/` 下最新的 `source-*.db`（切换前 SQLite 副本）作为模板，在一次性容器里运行导入工具的 `export-sqlite`，把 SQL Server 全部模型表写入模板副本，并校验：
   - 每表行数与逐行内容一致；
   - **存储格式**：两边都存在且语义相同的行，原始存储值必须逐字相同（GUID 大写文本、日期文本格式、decimal 文本），否则 IIS 旧代码的等值查询会失配。

## 不做什么

- 不改动生产库；不覆盖还原（`ops/mssql-restore.sh ... --confirm` 只在真实回滚时由人执行）。
- 回滚 SQLite 只存在于 `--rm` 容器内，只保留 JSON 报告。

## 运行

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/cutover-safety-drill/scripts/Invoke-CutoverSafetyDrill.ps1 -SkipConfirm
```

前置：`ops/deploy-urban-acceptance` 已用包含 `export-sqlite` 与 `mssql-backup` 侧车的镜像部署成功。
