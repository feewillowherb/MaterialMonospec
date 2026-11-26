# publish-urban-ota-lab-138（ops）

## 目的 / Goal

将 `MaterialClient.Urban` 的 Velopack 发布制品（含 **Full + Delta `.nupkg`**、`Setup.exe`、`releases.win.json`、`RELEASES`、`assets.win.json`）打包并上传至实验口 **138**（`http://192.168.3.138:5333`）网关挂载的 `/updates/urban/` 静态目录，随后校验 `releases.win.json` 可正常访问且包含目标版本。

Goal 槽：`ops-publish-urban-ota-lab-138` · Status: **active** · 路径：`pipelines/graphs/ops/publish-urban-ota-lab-138/`

## 非目标

- 不修改 `repos/` 业务代码
- 不重建或重启 138 上的 Docker 容器（静态目录为只读卷挂载，拷贝文件即时生效）
- 不提交 `secrets.local.yaml`、`runs/` 或 `.nupkg` / `.exe` 制品
- 不替代 OpenSpec；Agent 不判定 P3，cook 的 pass 不代表产品验收通过

## 模式

| 模式 | 动作 | 副作用 |
|------|------|--------|
| `pack`（默认） | 调用 `repos/MaterialClient/scripts/pack-urban-ota.ps1` 将当前 `MaterialClient.Urban` 打成 Velopack 包；当目标 `ReleaseDir` 已有上一版本（如 `2.0.0`）时，自动生成 **Delta** 增量包（如 `2.0.1-delta.nupkg`） | 仅写本机 `ReleaseDir` 与本次 `runs/<ts>/` |
| `upload -Apply` | 经共享 SSH/SCP 将 `ReleaseDir` 下所有 Velopack 制品上传至 138 的 `<remoteUpdatesDir>/urban`，并执行 HTTP 校验 | 写入 138 静态更新目录；须人闸 `upload-approval` |
| `verify` | 仅探测 `http://192.168.3.138:5333/updates/urban/releases.win.json` 与 `RELEASES` | 无 |

## Sockets

| | |
|--|--|
| Start | `urban-ota-source-ready` |
| End | `lab-138-ota-feed-verified` |
| Cook | `new-object` |

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[Bind config and secrets]
  PackN[Velopack pack Full and Delta]
  UploadN[SCP to 138 updates urban]
  VerifyN[HTTP verify releases.win.json]
  GateN[Human P3 Gate]
  BindN -->|urban-ota-source-ready| PackN --> UploadN --> VerifyN
  VerifyN -->|lab-138-ota-feed-verified| GateN
```

## Invoke

```powershell
$s = 'pipelines/graphs/ops/publish-urban-ota-lab-138/scripts/Invoke-PublishUrbanOtaLab138.ps1'

# 1. 本地打包（当 ReleaseDir 已有 2.0.0 时，打 2.0.1 会自动生成 delta.nupkg）
powershell -ExecutionPolicy Bypass -File $s -Mode pack -Version 2.0.1

# 2. 上传到 138 的 /updates/urban/（需先配置 secrets.local.yaml 并显式加 -Apply）
powershell -ExecutionPolicy Bypass -File $s -Mode upload -Version 2.0.1 -Apply

# 3. 仅校验 138 更新源
powershell -ExecutionPolicy Bypass -File $s -Mode verify -Version 2.0.1
```

脚本标 `experimental`。SSH / SCP 仅复用 `pipelines/_shared/ops/ssh/`。

## 人闸 / Gate

- 缺 `secrets.local.yaml` 或 `host` / `user` / `remoteUpdatesDir`
- `upload` 未传 `-Apply`
- 最终验收（P3）：用户确认 `pass` / `fail`

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | 本机打包完成或 SSH 可达 | Agent |
| P1 | Delta/Full 制品已生成并上传至 138 `<remoteUpdatesDir>/urban` | Agent |
| P2 | `GET /updates/urban/releases.win.json` 与 `RELEASES` 返回 200（`no-cache`）且包含目标版本与 Delta 资产 | Agent |
| P3 | 是否采纳本 run | 用户 |
