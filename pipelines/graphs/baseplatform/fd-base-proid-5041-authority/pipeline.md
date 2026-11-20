# fd-base-proid-5041-authority

## 目的 / Goal

在 135 的 `FD_Base` 上，为项目 `08dedbe1-6f19-61a6-1999-0d2e38041c54` 落下产品 `5041` 的一条授权。有效期为写入时刻起 1 年。`AuthStatus=1`、`CheckStatus=2` 沿用 2026-11-13 已核对的「已授权且审核通过」形状。

Goal 槽：`fd-base-proid-5041-authority`

Status: **active**

若替换旧验法：retired ← （无）

## 非目标

- 不新增或修改 `JC_Product`、菜单、角色、用户角色、密码
- 不复制 `MachineCode`、`AuthToken`、`AccessCode`
- 不刷新 Redis，不调用 SSO `GetToken`
- 不修改 `repos/` 业务代码
- 不提交 secrets / runs
- Agent 不宣布 P3 通过

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（可选；gitignore）
- `./secrets.example.yaml`
- 未提供 `connectionString` 时，读取 `repos/FdSoft.SSO/FdSoft.SSO.WebApi/appsettings.Development.json` 的 `Default`。服务器指纹必须是 `135`，库名必须是 `FD_Base`。

## Sockets

| | |
|--|--|
| Start | `fd-base-authority-idle` |
| End | `fd-base-authority-granted` |
| Cook | in-place |

## Context

- 指针：`target.serverFingerprint=135` 且 `target.database=FD_Base`
- 指纹：打开后的库名必须是 `FD_Base`
- 授权键：`ProId` + `ProductCode`，不用项目显示名
- 歧义：同一键出现多条未删除授权，或同一 `ProId` 出现多个 `CoId` 时停止

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-target]
  ReadN[read-current]
  PlanN[plan-grant]
  ApplyN[apply-or-dry-run]
  ValidateN[validate]
  BindN -->|fd-base-authority-idle| ReadN --> PlanN --> ApplyN --> ValidateN
  ValidateN -->|fd-base-authority-granted| GateN[Gate]
```

失败策略：`retries: 0`。默认 dry-run，不写入。`-Apply` 才提交。

## 行为

1. `bind-target`：解析连接并核对 135 / `FD_Base`。
2. `read-current`：确认 `JC_Product` 存在未删除且 `Status=1` 的 `5041`。从该 `ProId` 已有未删除授权复制 `CoId` 和审计用户。
3. `plan-grant`：没有未删除的 `5041` 行则计划插入；已有一条则只在未覆盖 1 年或状态不是已授权/已审核时延长 `AuthEndTime` 并修正状态。已覆盖则 no-op。不把更长的结束时间改短。
4. `apply-or-dry-run`：无 `-Apply` 时不写入。`-Apply` 在更新锁内重读后提交这一条变更。
5. `validate`：`-Apply` 后重读该行。dry-run 只记录计划。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| plan | yes | `prepare/plan.json` |
| summary | yes | `summary.json` |
| report | yes | `report.md` |
| manifest | yes | `manifest.yaml` |

证据不写连接串、口令、`CoId`、用户 Id 和用户名。

## Invoke

experimental

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/fd-base-proid-5041-authority/scripts/Invoke-FdBaseProId5041Authority.ps1
```

写入：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/fd-base-proid-5041-authority/scripts/Invoke-FdBaseProId5041Authority.ps1 -Apply
```

## 人闸 / Gate

- `environment: shared`（135 实验库，不是本机库）
- 缺连接或指纹不符时停止
- ingest 写入必须带 `-Apply`
- 最终验收：用户 `pass` / `fail`

## 判定级别

| 级 | 含义 | 谁判 |
|----|------|------|
| P0 | 连上 135 的 `FD_Base` | Agent 记录 |
| P1 | 定位到产品 `5041` 和该 `ProId` 的组织模板 | Agent 记录 |
| P2 | `-Apply` 后未删除授权已覆盖 1 年，且为已授权、已审核 | Agent 记录 |
| P3 | 业务上接受这次授权 | **用户** |

## Handoff

Output socket：`fd-base-authority-granted`。下游若要接，须声明对齐该态。本图不登录 SSO。
