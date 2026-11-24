# deploy-urban-acceptance（ops）

## 目的 / Goal

把 UrbanManagement 微服务工程拆分后的栈（每个服务一个工程、一个镜像；网关 `um-gateway` + 角色 `um-ingest` ×2（`um-ingest`、`um-ingest-2`）/ `um-attachment` / `um-realtime` / `um-admin` / **`um-recycle`** / `um-worker` + 一次性 `um-migrator` + `mssql` + `redis`）部署到 Docker 虚拟机（正式口 **191**）。

**2026-11-04 切流后：** 本 Graph 是**日常正式发版**入口（正式口 `5233` 已指向 Docker 栈）。slug / goal 仍带 `acceptance` 为历史命名，不另起 Graph。

蓝图：[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)。上游：`ops/fev-u2-docker`、`ops/fev-u10-uploads-smb`、`ops/urban-cutover`。

Goal 槽：`ops-deploy-urban-acceptance` · Status: **active** · 路径：`pipelines/graphs/ops/deploy-urban-acceptance/`

发版后预期：[`expect/after-deploy.md`](./expect/after-deploy.md)（叙述）与 [`expect/after-deploy.yaml`](./expect/after-deploy.yaml)（机器可读）。Cook 的 P2 与这些断言对齐。

## Profile（`config.yaml` → `target.deployProfile`）

| Profile | 用途 | GovSync | 外部健康 |
|---------|------|---------|----------|
| `production`（**默认**） | 正式发版 | 允许 **仅** `um-worker` 注册；其它角色必须为 0 | 宿主 `externalProbePort`（**5233**）→ 200 |
| `acceptance` | 历史干跑（Sync 关闭） | **任何**角色不得注册 GovSync | 同上（宿主 / VM gateway **5233**） |

切流后日常发版保持 `deployProfile: production`。需要复现「关同步验收口径」时再临时改为 `acceptance`。

## 非目标

- 不改宿主机：`5233` portproxy、防火墙由人执行（人闸 `host-portproxy-required`）
- 不在本 Graph 内切换正式口（见 `ops/urban-cutover`）
- 不自动扩容 VM（`vm-memory-below-threshold`）
- 历史 **5333 / 5334** 已退役；正式默认 **5233 / 5234**

## 模式

| 模式 | 动作 | 副作用 |
|------|------|--------|
| `deploy`（须 `-Apply`） | 本机 `npm run build`（Recycle client）+ `dotnet publish` **八**个服务工程（含 Recycle）+ DataImport → 打包（含 `otel-collector.yaml`）→ scp → 虚拟机：解包、Uploads cifs、`.env` 写入 Admin/Recycle SSO、按服务 `docker build`（8 镜像）、起栈、空库导入、检查 gateway **与** Recycle `:recyclePublicPort` 健康 | 改虚拟机（幂等）；库非空则跳过导入 |
| `deploy -ResetDatabase` | 同上，但先删库再导入 | 丢数据（人闸 `reset-database-approval`） |
| `verify` | 只读检查 + 本机探测 `externalProbePort`（5233） | 无 |

**重复执行：** `.env` 已存在则保留（含正式环境已开启的 Sync/Polling）；库非空跳过导入；每次 run 为**八**镜像打同一标签 `<run>` 并更新 `latest`。

## 发版后预期（摘要）

| 对象 | 预期 |
|------|------|
| 宿主 `5233` | `/health/ready` → 200 |
| VM gateway `5233` | ready/live/gateway health → 200 |
| VM Recycle `5234` | `/health/live` → 200；DLL 含 `UrbanManagement.Recycle` |
| 镜像 | `SERVICE_IMAGES` = **8** |
| production GovSync | 仅允许 worker；非 worker = 0；worker snapshot ≥ 1 |
| Uploads | 容器内 cifs/smb；tus 可写；无容器内 secret json |

完整表与 summary 字段见 `expect/after-deploy.md`。

**配置源：** 切流后 IIS `wwwroot` 共享常不可读 → `CONFIG_SOURCE=local` 为预期，不单独判 fail。

## 宿主机侧（人执行）

- 正式口：宿主 `5233` → VM `5233`（同号）；Recycle VM `5234`
- 维护见 `ops/urban-cutover` / 人工 portproxy（含 Recycle 5234 是否对外）

## Invoke

```powershell
$s = 'pipelines/graphs/ops/deploy-urban-acceptance/scripts/Invoke-DeployUrbanAcceptance.ps1'
powershell -ExecutionPolicy Bypass -File $s -Mode deploy -Apply -SkipConfirm
powershell -ExecutionPolicy Bypass -File $s -Mode verify -SkipConfirm
```

或：`/run-pipeline ops/deploy-urban-acceptance`

## 结果规则（写死在 cook）

| 证据 | result |
|------|--------|
| 远端完成；网关/角色路由与拆分检查通过；Recycle live；worker 注册快照；GovSync 符合当前 profile；八镜像与程序集边界正确；SMB Uploads；外部口按 profile 就绪 | `pass` |
| 栈健康但 VM 可用内存不足 | `blocked`（`vm-memory-below-threshold`） |
| 栈健康但宿主 `5233` 不通 | `blocked`（`host-portproxy-required`） |
| SSH 失败 | `blocked` |
| 其他 | `fail` |

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | SSH 可达 | Agent |
| P1 | 远端脚本 exit 0 | Agent |
| P2 | 栈健康（含 profile 下的 GovSync / 双口规则） | Agent |
| P3 | 是否采纳本 run（业务观感） | 用户 |

## Handoff

Output socket：`urban-acceptance-deployed`（历史名）。cook 后 Agent **MUST** 回写蓝图 `05` 的发布 run identity。Pipeline pass **不是**产品 `APPROVED`。
