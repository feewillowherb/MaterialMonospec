# design-brief — waybill-softdelete-join-probe

```yaml
id: waybill-softdelete-join-probe
family: probe
goal: waybill-softdelete-join-gap
status: active
purpose: >-
  只读探针现场 SQLite：区分材料/供应商硬删与软删，量化 Waybill 订单查询在
  active-only join 下丢失材料名/供应商名的缺口（不修业务）。
sockets:
  start: sqlite-idle
  end: softdelete-gap-probed
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不写库 / 不 ingest
  - 不提交 secrets/runs
  - 不替代规范与 CI
  - Agent 不宣布 L3 通过
environment: local
stopOnError: false
target:
  databaseAbs: from secrets.local.yaml
  tables: [Waybills, Materials, Providers, WaybillMaterials]
secretsKeys: [databaseAbs]
steps:
  - bind-db
  - count-masters
  - probe-waybill-joins
  - probe-waybill-materials
  - write-evidence
collectors: [prepare, samples, summary, report]
adapters:
  probe: scripts/Invoke-WaybillSoftdeleteJoinProbe.ps1 + probe-softdelete-join.ts
humanGates: [missing-secrets, acceptance]
failurePolicy:
  retries: 1
  stopOnError: false
```

## Preflight snapshot（生成前只读摸底，非 run 证据）

现场库 `D:\新建文件夹\固废\1112\MaterialClient.db`（2026-11-02）：

| 指标 | 值 |
|------|-----|
| Materials | 20（软删 10 / 活跃 10） |
| Providers | 338（软删 3 / 活跃 335） |
| Waybills `IsDeleted=0` | 8848 |
| Waybill→Material **硬缺失** | 0 |
| Waybill→Material **软删引用** | **836** |
| Waybill→Provider 硬缺失 / 软删 | 0 / 1 |
| WaybillMaterials→Material 软删 | 803 |

→ 主因是 **软删除 + 查询侧过滤**，不是行被物理删光。正式结论以 cook `runs/` 为准。
