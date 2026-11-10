# ops / urban-cutover

切换日 Graph：把验收中的 Phase 3 栈切到现网流量（蓝图 [`05`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) §3）。

> **状态（2026-11-04）：** Human 确认正式口 `5233` 已切入 Docker Phase 3（回写 [`05` §3.1](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)）。本 Graph 保留用于核对 / 复盘；日常发版用 `ops/deploy-urban-acceptance`。

## 做什么

| Mode | 默认 | 作用 |
|------|------|------|
| `check` | 是 | 只读：固定 IP、SMB、十个服务健康、同步开关仍关、`5333` 外网 ready；并探测宿主 `5233` 是否仍被 IIS 占用 |
| `cutover` | 需 `-Apply` | 虚拟机侧：要求 IIS 已停（`5233` 不通）→ 用现网 SQLite 重置并导入 → 只打开 `um-worker` 同步 → 健康检查 |

## 不做什么（人在宿主执行）

- 不停 IIS、不切 `5233` 端口转发 / `UM-Proxy`（必须在宿主管理员 PowerShell / IIS 管理器完成，见 runbook 步骤 2、3、7）
- 不改 MaterialClient
- 不自动宣布产品通过

## 宿主命令（切换窗口）

停 IIS 后复制库（路径按现网实际调整）：

```powershell
# 确认 IIS 已停：5233 应不通
Test-NetConnection 127.0.0.1 -Port 5233
# 切入口（D2-A），在 Graph cutover 与 e2e 通过之后：
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=5233 connectaddress=192.168.250.10 connectport=5333
```

## 运行

```powershell
# 切换前只读检查
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/urban-cutover/scripts/Invoke-UrbanCutover.ps1 -Mode check -SkipConfirm

# 切换日（人已停 IIS、已把现网 db 放到 -SourceDb）
powershell -ExecutionPolicy Bypass -File pipelines/graphs/ops/urban-cutover/scripts/Invoke-UrbanCutover.ps1 `
  -Mode cutover -Apply -SourceDb "D:\path\UrbanManagement.db" -SkipConfirm
```

前置：`ops/deploy-urban-acceptance` 已部署 Phase 3；secrets 复用 `../deploy-urban-acceptance/secrets.local.yaml`。
