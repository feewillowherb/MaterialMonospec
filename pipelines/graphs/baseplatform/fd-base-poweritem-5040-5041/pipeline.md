# fd-base-poweritem-5040-5041

## 目的 / Goal

生成可在 **129** `FD_Base` 手工执行的 SQL：为产品 **5040 / 5041** 插入与 135 同形的路由菜单（`JC_PowerItem` 各 2 条：根 + 子），并给已有 `JC_Role` 写入 `PowerCode=11…`（2048 位）。

权威 SQL：`./sql/insert-jc-poweritem-5040-5041.sql`  
插入后预期：`./expect/after-insert.md`（叙述）与 `./expect/after-insert.yaml`（机器可读）

Cook **不连库、不执行**。

Goal 槽：`fd-base-poweritem-5040-5041`  
Status: **active**

## 非目标

- 不写产品 / 授权 / 用户角色
- 不刷新 Redis
- 不断言 GetToken 成功
- Agent 不宣布 P3

## 插入后预期（摘要）

执行并 `COMMIT` 后：

| 对象 | 预期 |
|------|------|
| `JC_PowerItem` 5040 | 未删 **2** 行：根 `xiaoshanUrbanRoot` + 子「项目管理」`/projects`；ItemType=1；PowerCode 头 `1` / `01`；Len=2048 |
| `JC_PowerItem` 5041 | 未删 **2** 行：根 `xiaoshanResourceRoot` + 子「车辆管理」`/vehicles`；同上 |
| `JC_Role` 5040/5041 | 各 ≥1 未删角色；PowerCode 头 **`11`**；Len=**2048**（129 已知 RoleId 106 / 107） |

完整表与验收 SELECT 见 `expect/after-insert.md`。

## Invoke

打开并在 129 `FD_Base` 整段执行到 `COMMIT`：

`pipelines/graphs/baseplatform/fd-base-poweritem-5040-5041/sql/insert-jc-poweritem-5040-5041.sql`

对照脚本末尾 SELECT 与 `expect/after-insert.md` §3。

## 判定级别

| 级 | 含义 |
|----|------|
| P0 | 权威 SQL 与 expect 文件可读 |
| P1 | SQL 含 5040/5041 菜单插入与角色 PowerCode 更新 |
| P2 | 人工执行后库状态匹配 `expect/after-insert.*` |
| P3 | 用户接受（仅用户） |
