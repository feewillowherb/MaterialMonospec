# design-brief — solidwaste-oct-export-include-softdelete

```yaml
id: solidwaste-oct-export-include-softdelete
family: transform
goal: solidwaste-oct-export-include-soft-masters
status: active
purpose: >-
  只读导出 2026-10 固废已完成运单 xlsx；列映射对齐应用 ExcelExportService；
  材料/供应商名称解析包含软删除行。
sockets:
  start: sqlite-idle
  end: xlsx-exported
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不写现场库
  - 不提交 secrets/runs/out
  - Agent 不宣布 L3 通过
environment: local
stopOnError: true
target:
  databaseAbs: from secrets
  period: 2026-10
secretsKeys: [databaseAbs]
steps: [bind-db, query-october, resolve-masters, map-rows, write-xlsx]
collectors: [prepare, xlsx, csv, summary, report]
adapters:
  transform: Invoke-SolidwasteOctExport.ps1 + export-solidwaste-october.ts
humanGates: [missing-secrets, acceptance]
```

## Preflight（生成摸底，非正式 run）

- 源：`D:\新建文件夹\固废\1112\MaterialClient.db`
- 2026-10 固废已完成 Waybill：**864**
- 其中材料已软删引用：**39**
