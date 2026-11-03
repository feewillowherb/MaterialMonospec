# ops / cutover-safety-drill

切换安全网演练：证明切换后若要回滚到 IIS，**能把 SQL Server 的全部数据导回 SQLite**（蓝图 D6）。数据库备份按用户决定不做（D15）。

## 做什么

回滚导出：取 `/opt/urbanmanagement/import/` 下最新的 `source-*.db`（切换前 SQLite 副本）作为模板，在一次性容器里运行导入工具的 `export-sqlite`，把 SQL Server 全部模型表写入模板副本，并校验：

- 每表行数与逐行内容一致；
- **存储格式**：两边都存在且语义相同的行，原始存储值必须逐字相同（GUID 文本大小写、日期文本格式、decimal 文本），否则 IIS 旧代码的等值查询会失配。

## 不做什么

- 不改动生产库；回滚 SQLite 只存在于 `--rm` 容器内，只保留 JSON 报告。

## 运行

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/cutover-safety-drill/scripts/Invoke-CutoverSafetyDrill.ps1 -SkipConfirm
```

前置：`ops/deploy-urban-acceptance` 已用包含 `export-sqlite` 的镜像部署成功。
