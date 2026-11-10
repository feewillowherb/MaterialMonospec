# UrbanManagement — Docker 生产发布与运维

> **现行生产手册**（2026-11-04）。正式入口：`http://191.12.234.212:5233/` → 宿主 → Hyper-V Ubuntu 虚拟机 `192.168.250.10:5333`（`um-gateway` Phase 3）。
> IIS + SQLite 手册已标 `HISTORICAL`，见 [windows-server-deploy.md](./windows-server-deploy.md)（仅回滚参考）。

**适用项目**: `repos/UrbanManagement`（.NET 10 / ABP / 多宿主微服务 + Docker Compose / MSSQL / Redis）

蓝图与切换证据：[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/`](../2026-11-02-urbanmanagement-docker-mssql-upgrade/00-调研总览.md)（端口分层见 [`05` §2.0](../2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)；切流回写见 [`05` §3.1](../2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)）。

---

## 1. 拓扑（生产）

| 项 | 值 |
|----|-----|
| 正式口 / 发版探针 | `191.12.234.212:5233`（宿主 portproxy → VM `5333`；Graph `externalProbePort=5233`） |
| VM gateway 发布口 | `UM_PUBLIC_PORT=5333` → 容器 `8080`；**保持不变**（宿主退役对外 5333 后也不改 VM 口） |
| 宿主历史 5333 旁路 | **已退役**；勿再作为发版/健康检查入口 |
| 虚拟机 | `192.168.250.10`（`UM-NAT`）；SSH `vanilla@191.12.234.212:2222` |
| 栈 | `um-gateway` + `um-ingest`×2 + `um-attachment` + `um-realtime` + `um-admin` + `um-worker` + `mssql` + `redis` |
| 发版 Graph | `ops/deploy-urban-acceptance` 默认 `deployProfile=production`（允许 worker GovSync） |
| 附件 | SMB `um-uploads` → 宿主 `C:\wwwroot\UrbanManagement\Uploads`（容器 `/app/Uploads`） |
| 配置 / 密钥 | 虚拟机 `/opt/urbanmanagement/.env` + secrets；**不要**把生产密钥写进仓库 |

Compose 权威：`repos/UrbanManagement/deploy/docker/`。

---

## 2. 发版（推荐）

使用 Graph（本机 publish → SCP → 远端 build/compose）：

```powershell
# 只读核对
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/deploy-urban-acceptance/scripts/Invoke-DeployUrbanAcceptance.ps1 -Mode verify

# 发版（需人闸 -Apply）
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/deploy-urban-acceptance/scripts/Invoke-DeployUrbanAcceptance.ps1 -Mode deploy -Apply
```

约定与密钥：`pipelines/graphs/ops/deploy-urban-acceptance/`（`secrets.local.yaml`，勿提交）。

**不要**对正式环境再跑 `scripts/UrbanManagement/Publish-UrbanManagement.ps1`（IIS robocopy）；该脚本仅作观察期回滚到旧站点时的参考。

---

## 3. 日常运维

| 场景 | 做法 |
|------|------|
| 健康 | 外部 `http://191.12.234.212:5233/health/live`；内部 `docker compose ps` / 各角色 `/health/ready` |
| 日志 | `docker compose logs -f um-ingest`（或对应服务）；文件日志在 `um-logs` 卷 |
| 改配置 | 改虚拟机 secrets / `.env` → 重建相关容器（以重启为准） |
| 开机 | Docker `enabled` + 容器 `restart: unless-stopped`；虚拟机 `AutomaticStartAction=Start` |
| 回滚到 IIS | 见蓝图 [`05` §4](../2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)；观察期内保留 IIS 站点与切换前 SQLite |

更完整的 FEV、入口方案、切换/回滚步骤仍以蓝图 [`05`](../2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) 为准。
