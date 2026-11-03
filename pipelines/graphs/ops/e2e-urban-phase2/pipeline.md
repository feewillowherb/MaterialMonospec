# e2e-urban-phase2（ops）

## 目的 / Goal

用合成的 MaterialClient.Urban 客户端，从本机经公网入口 `http://191.12.234.212:5333`（宿主 portproxy → 网关）跑一遍客户端契约（蓝图 [`02`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/02-客户端接口兼容契约.md)）在 Phase 2 角色拆分栈上的端到端流程，并证明 SignalR Redis backplane 能把 ingest 进程发出的推送送达连在 console 上的客户端。

Goal 槽：`ops-e2e-urban-phase2` · Status: **active** · 路径：`pipelines/graphs/ops/e2e-urban-phase2/` · 上游：`ops/deploy-urban-acceptance`

## 流程

| 步骤 | 内容 | 走哪个角色 |
|------|------|-----------|
| Hub | WebSockets 连接 + `SayHello` 往返；另开 SSE 连接 `SayHello`（代理不缓冲） | console |
| 在线 | `UploadStatus`（合成 ProId / ClientId，加入组 `pro_{ProId}`）→ `GET /api/app/device-status/client-list` 出现且 `isConnected=true` | console |
| R9 / R10 | tus 创建（`Location` 按客户端规则解析后必须是对外地址；tusdotnet 返回相对路径）→ HEAD→ PATCH → `tus/commit` 得附件 ID | ingest |
| R2 | `receive` 记录 A（带附件）、记录 B，均为异常记录 | ingest |
| 审批 A | 经网关 `approve` → 客户端收到 `WeighingRecordApproved`；console 日志有推送行 | console |
| R3 / R4 | `pending-server-approval-sync` 含 A → `ack-approval-sync` → 不再含 A | ingest |
| 审批 B | SSH 在 `um-ingest` 容器内直接调 `approve`：推送由 ingest 进程发出，只有经 Redis backplane 才能到 console 上的客户端；ingest 日志有推送行、console 没有 | ingest → Redis → console |
| 清理 | 删除本 run 的记录、附件行与 `Uploads/E2E-PROBE/` 文件、在线状态行、Redis 键；再计数确认为 0 | VM |

不覆盖：R1 激活（需真实激活码）、R5 / R6 卡口与成品、R7 / R8 Base64 与 multipart、R11 旧版 `/Api/Post`、日志拉取。

## 副作用

写入验收库与共享 `Uploads`（专用目录 `E2E-PROBE`），每次 run 结束都清理并核对残留为 0。ProId 每次新生成，不碰真实项目。客户端连接注册表（Redis 单键）里可能留下一条该 ClientId 的离线条目，按 TTL 自然过期。

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/e2e-urban-phase2/scripts/Invoke-E2EUrbanPhase2.ps1 -SkipConfirm
```

或：`/run-pipeline ops/e2e-urban-phase2`

## 结果规则（写死在 cook）

`report.md` 的每项检查都通过 → `pass`；任一失败 → `fail`；没有任何证据 → `blocked`。检查项：`hub-websockets`、`hub-sse`、`client-online`、`tus-r9`、`tus-r10-commit`、`receive-r2`、`approve-push-console`、`pending-ack-r3-r4`、`backplane-ingest-push`、`cleanup`。

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | 经网关建立 Hub WebSockets 连接 | Agent |
| P1 | 客户端跑完、远端脚本执行 | Agent |
| P2 | 全部检查通过 | Agent |
| P3 | 是否采纳 | 用户 |

## Handoff

Output socket：`urban-phase2-e2e-proved`。cook 后 Agent 把 Run identity 与结果回写蓝图 `05` §5。产品通过仍须 Human `APPROVED`。
