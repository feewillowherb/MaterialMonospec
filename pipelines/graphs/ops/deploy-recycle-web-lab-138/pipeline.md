# deploy-recycle-web-lab-138（ops）

## 目的 / Goal

只把 Recycle Web（`UrbanManagement.Recycle`）发布到实验口 138，并让已有 compose 项目的 `um-recycle` 用标签 `lab` 重新拉起。其余七个服务的镜像和容器不动。

指针：[`docs/2026-11-18-recycle-auth-lab-publish/`](../../../../docs/2026-11-18-recycle-auth-lab-publish/00-调研总览.md) 中的 `http://192.168.3.138:5333`。Recycle 对外端口取仓库 compose 的 `UM_RECYCLE_PUBLIC_PORT` 默认值 **5334**。

要发布整套服务时用 `ops/deploy-urban-lab-138`。本图与它共用同一台主机、同一个 compose 项目和同一个标签 `lab`。

Goal 槽：`ops-deploy-recycle-web-lab-138` · Status: **active** · 路径：`pipelines/graphs/ops/deploy-recycle-web-lab-138/`

## 非目标

- 不修改 `repos/` 业务代码
- 不重建 Gateway、Ingest、Attachment、Realtime、Admin、Worker
- 不整份替换 138 上的 `compose.yaml` 或 `.env`，不把 Linux 虚拟机 compose 拷上去。每次发布只把 Uploads 改成绑定 `C:\wwwroot\UrbanManagement\Uploads`，并给 `um-recycle` 挂上这块盘
- 不写入 GovProject，不调用客户端上传，不把同步标成成功
- 不提交 secrets / runs，不把密钥写进证据
- 不替代 OpenSpec。Agent 不判定 P3，cook 的 pass 不是产品通过

## 模式

| 模式 | 动作 | 副作用 |
|------|------|--------|
| `publish`（默认） | 本机 `npm run build`（Recycle client 存在时）+ `dotnet publish Recycle` + 打成一个 bundle | 只写本次 `runs/<ts>/prepare/` |
| `deploy -Apply` | 上传 bundle，138 上构建 Recycle 镜像（上下文只有该服务目录），把 Uploads 绑到 `C:\wwwroot\UrbanManagement\Uploads`，再 `compose up --no-deps um-recycle`。`/app/Uploads` 不是这块盘则失败 | 改 138 上的 Recycle 镜像、容器和 Uploads 挂载。须人闸 `deploy-approval` |
| `verify` | 只探测 Recycle `5334/health/live` | 无 |

`deploy -Apply -WithMigrator` 额外发布并构建 `Migrator` 镜像，先重建 `um-migrator` 并等它以 0 退出，再重建 `um-recycle`。带新 EF migration 的发布必须加这个开关：Recycle 宿主启动时不会自己迁移数据库。

138 的 compose 必须已经有 `um-recycle`。远端脚本发现没有该服务就停止，不会代写 compose。`um-recycle` 的连接串、Redis 和 `RecyclePersistence__BoundSourceProId` 留在宿主机 compose / `.env`，用 `${UM_DB_PASSWORD}`，不进本仓库。

镜像标签由远端进程的 `UM_TAG=lab` 覆盖，不改宿主机 `.env`。镜像使用 Dockerfile target `service`。远端文件名带 `recycle` 前缀，不覆盖 `deploy-urban-lab-138` 留在同一目录下的 bundle 和日志。

图片目录按 `ca70954` 的正式发版：容器 `/app/Uploads` 必须落在 Windows 磁盘 `C:\wwwroot\UrbanManagement\Uploads`。发布前创建该目录，把 compose 的 `x-uploads` 改成这块盘的 bind，并写入 `um-recycle` 的 volumes。重建容器不会删这块盘上的文件。启动后检查 Recycle 容器挂载，不是这块盘就以 `BUILD_FAILED uploads_not_windows_disk` 停止。

## Sockets

| | |
|--|--|
| Start | `lab-138-sources-ready` |
| End | `lab-138-recycle-web-running` |
| Cook | `new-object` |

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[Bind secrets]
  PublishN[Publish bundle]
  UploadN[Upload]
  BuildN[Recycle image build]
  MigrateN[um-migrator]
  UpN[compose up um-recycle]
  HealthN[Health]
  GateN[Gate]
  BindN -->|lab-138-sources-ready| PublishN --> UploadN --> BuildN --> MigrateN --> UpN --> HealthN
  HealthN -->|lab-138-recycle-web-running| GateN
```

`publish` 停在 bundle。`verify` 只走 Health。没有 `-WithMigrator` 时跳过 `um-migrator`。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| prepare | publish / deploy | `prepare/` |
| scp | deploy | `scp/meta.json` |
| ssh | deploy | `ssh-ready/` `ssh-launch/` `ssh-log/` |
| summary | 总是 | `summary.json` |
| report | 总是 | `report.md` |

`summary.json` 与 `manifest.yaml` 只用仓库相对路径。SSH 证据沿用共享 helper，其中不得出现密码。

## Invoke

```powershell
$s = 'pipelines/graphs/ops/deploy-recycle-web-lab-138/scripts/Invoke-DeployRecycleWebLab138.ps1'
powershell -ExecutionPolicy Bypass -File $s -Mode publish
powershell -ExecutionPolicy Bypass -File $s -Mode deploy -Apply
powershell -ExecutionPolicy Bypass -File $s -Mode deploy -Apply -WithMigrator
powershell -ExecutionPolicy Bypass -File $s -Mode verify
```

或：`/run-pipeline ops/deploy-recycle-web-lab-138`

脚本标 experimental。SSH / scp 只用 `pipelines/_shared/ops/ssh/`。

## 人闸 / Gate

- 缺 `secrets.local.yaml` 或 host / user / remoteWork / remoteComposeDir
- `deploy` 没有 `-Apply`
- 138 compose 没有 `um-recycle`
- 最终验收：用户 `pass` / `fail`

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | SSH 可达，或 `publish` 只在本机打出 bundle | Agent |
| P1 | 远端脚本写出 `BUILD_DONE`，或 `verify` 收到 HTTP 响应 | Agent |
| P2 | Recycle 5334 `/health/live` 是 200 | Agent |
| P3 | 是否采纳本 run | 用户 |
