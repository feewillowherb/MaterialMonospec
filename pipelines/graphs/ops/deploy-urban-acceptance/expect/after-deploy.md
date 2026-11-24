# 发版后预期结果（191 正式口 / Docker VM）

`deploy`（`-Apply`）或 `verify` 成功后，下列断言应全部成立。  
对照本次 `runs/<ts>/summary.json`、`prepare/deploy-<mode>-parse.json` 的 markers，以及本机对宿主口的探测。

默认 profile：**production**（`config.yaml` → `target.deployProfile`）。

## 1. 拓扑与端口

| 项 | 预期 |
|----|------|
| 宿主正式口 | `http://191.12.234.212:5233/health/ready` → **200**（`EXTERNAL_READY_HTTP`） |
| VM gateway | `publicPort` **5333**（仅 VM 内；宿主不再用 5333）`READY_HTTP`/`LIVE_HTTP`/`GW_HEALTH_HTTP` → **200** |
| VM Recycle | `recyclePublicPort` **5334**；`RECYCLE_LIVE_HTTP` → **200** |
| Recycle ready | `RECYCLE_READY_HTTP` 记录在案（P2 以 live 为准；ready 非 200 须在 report 说明） |
| SSO（`.env`） | `UM_ADMIN_SSO_BASE_URL` 非空；Admin 产品码默认 **5040**；Recycle 固定 **5041** |

## 2. 镜像与服务

| 项 | 预期 |
|----|------|
| 唯一 `urbanmanagement-*` 镜像数 | **`SERVICE_IMAGES` = 8**（Gateway / Ingest / Attachment / Realtime / Admin / Recycle / Worker / Migrator） |
| 角色 ready | `um-ingest`、`um-ingest-2`、`um-attachment`、`um-realtime`、`um-admin`、`um-worker` 的 `ROLE_*_READY` 均为 **200** |
| Migrator | `MIGRATOR_EXIT` = **0**；`LOG_MIGRATOR_MIGRATED` ≥ 1 |
| 无旧 um-app | `UM_APP_PRESENT` = **0** |
| Recycle 程序集 | `ROLE_RECYCLE_SERVICE_DLLS` 含 **`UrbanManagement.Recycle`** |
| 角色程序集边界 | 各角色仅自身服务 DLL；tus 仅 attachment；Blazor 仅 admin；import tool 仅 worker |

## 3. 路由与 backplane（gateway）

| 探测 | 预期 |
|------|------|
| tus OPTIONS `/api/urban-attachment/tus/` | **204** + 非空 `Tus-Version` |
| hub GET `/hubs/devicestatus` | **400** |
| negotiate POST | **200** |
| gateway `/internal/...` | **404** |
| admin → realtime internal | **200** |
| admin 根 | **200** 或 **302**；realtime 根 **404** |
| attachment tus OPTIONS | **204**；ingest tus OPTIONS **≠ 204** |
| Redis `UM:signalr*` | `BACKPLANE_CHANNELS` ≥ **1** |

## 4. GovSync / Worker（按 profile）

| Profile | 预期 |
|---------|------|
| **production**（默认） | 非 worker 角色 `LOG_*_GOVSYNC_REGISTERED` 合计 **0**；worker 允许 ≥0；`LOG_WORKER_SNAPSHOT_REGISTERED` ≥ **1**；非 worker snapshot = **0** |
| **acceptance** | 全部角色 GovSync 注册合计 **0** |

## 5. Uploads / 配置 / 导入

| 项 | 预期 |
|----|------|
| 容器 Uploads 文件系统 | cifs / smb2 / smb3；`UPLOADS_ON_WINDOWS` = yes |
| tus 可写 | `CONTAINER_TUS_WRITABLE` = yes |
| 容器内无 `appsettings.secret.json` | `CONTAINER_SECRET_JSON` = absent |
| Import | `done` 或 `skipped-nonempty`（非空库跳过为预期） |
| CONFIG_SOURCE=local | 切流后 IIS 共享不可读时为**预期**，单独不构成 fail |

## 6. 内存与人闸

| 项 | 预期 |
|----|------|
| VM 可用内存 | ≥ `memMinAvailableMb`（默认 500）→ `MEM_OK=yes`；否则 result=`blocked` / `vm-memory-below-threshold` |
| 宿主 5233 不通、栈内健康 | result=`blocked` / `host-portproxy-required` |

## 7. summary.json 对照字段

| 字段 | pass 时 |
|------|---------|
| `result` | `pass` |
| `deployProfile` | `production`（日常） |
| `externalReady` | `200` |
| `externalProbePort` | `5233` |
| `vmPublicPort` | `5333` |
| `recyclePublicPort` | `5334` |
| `recycleLive` | `200` |
| `levels.P0` / `P1` / `P2` | true / true / true |
| `levels.P3` | `user-only`（仅用户） |

## 8. 非目标（本 expect 不断言）

- 宿主是否已对 5334 做 portproxy
- Admin / Recycle 浏览器登录观感（属 P3）
- 客户端称重上传 / 业务 ICD
- Pipeline pass ≠ 产品 `APPROVED`
