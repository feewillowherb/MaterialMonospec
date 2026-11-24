# fd-base-product-5040-5041

## 目的 / Goal

生成可在 **129** `FD_Base` 手工执行的 SQL：为 `dbo.JC_Product` 落下

| ProductCode | ProductName |
|-------------|-------------|
| 5040 | 萧山城管管理平台 |
| 5041 | 萧山资源化利用网页端 |

缺省字段按人工提供的模板形状写死（`OrganizeType=2`、`ProductType=3`、`CoId=1`、Url/CallBackUrl、创建/更新人 35/朱文锦、`DbConn` 等）。**不依赖库中是否存在 5020**。Cook **不连库、不执行**。

Goal 槽：`fd-base-product-5040-5041`

Status: **active**

若替换旧验法：retired ← （无；本图由「直连写入」改为「只生成 SQL」）

## 非目标

- 不连接、不写入任何数据库
- 不写菜单、角色、用户角色、产品授权
- 不刷新 Redis / SSO 产品缓存
- 不修改 `repos/` 业务代码
- 不提交 secrets / runs
- Agent 不宣布 P3 通过；人工在 129 执行 SQL 后的业务接受仍属用户

## 配置指针

- `./config.yaml`
- `./sql/upsert-jc-product-5040-5041.sql`（权威 SQL 源）
- 无需 `secrets.local.yaml`

## Sockets

| | |
|--|--|
| Start | `fd-base-product-sql-idle` |
| End | `fd-base-product-sql-ready` |
| Cook | in-place |

## Context

- 指针：`target.serverFingerprint=129`、`target.database=FD_Base`（给人看的落点；cook 不校验连接）
- 形状：见 `sql/` 头注释与 `config.yaml` 的 `templateShape`
- 目标键：`ProductCode` 5040 / 5041；新建行 LastLogin* 为 0 / NULL

## 状态机 / Cook chain

```mermaid
flowchart LR
  ReadN[read-sql-source]
  EmitN[emit-run-artifacts]
  ValidateN[validate-artifacts]
  ReadN -->|fd-base-product-sql-idle| EmitN --> ValidateN
  ValidateN -->|fd-base-product-sql-ready| GateN[Gate]
```

失败策略：`retries: 0`。无 DB 写路径。

## 行为

1. `read-sql-source`：读取 `sql/upsert-jc-product-5040-5041.sql`。
2. `emit-run-artifacts`：复制到本次 `runs/<ts>/prepare/upsert-jc-product-5040-5041.sql`，并写 plan / summary / report / manifest。
3. `validate-artifacts`：确认产物含 5040、5041，且文件非空。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| sql | yes | `prepare/upsert-jc-product-5040-5041.sql` |
| plan | yes | `prepare/plan.json` |
| summary | yes | `summary.json` |
| report | yes | `report.md` |
| manifest | yes | `manifest.yaml` |

## Invoke

experimental

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/fd-base-product-5040-5041/scripts/Invoke-FdBaseProduct50405041.ps1
```

人工在 129 执行：

```text
runs/<ts>/prepare/upsert-jc-product-5040-5041.sql
```

或直接用图内权威源：

```text
pipelines/graphs/baseplatform/fd-base-product-5040-5041/sql/upsert-jc-product-5040-5041.sql
```

## 人闸 / Gate

- cook 只产文件；在 129 执行 SQL 由人决定
- 最终验收：用户 `pass` / `fail`（是否接受生成的 SQL / 执行结果）

## 判定级别

| 级 | 含义 | 谁判 |
|----|------|------|
| P0 | 权威 SQL 源可读且非空 | Agent 记录 |
| P1 | 产物含 5040 / 5041，且不依赖 5020 运行时查询 | Agent 记录 |
| P2 | run 目录已写出完整 SQL 与证据包 | Agent 记录 |
| P3 | 业务上接受该 SQL（及可选的人工执行结果） | **用户** |

## Handoff

Output socket：`fd-base-product-sql-ready`。下游若要在库上验收，须另开 probe / 人手执行，不由本图代写。
