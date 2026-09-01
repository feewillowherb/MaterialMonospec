# solidwaste-pair-ingest（materialclient）

## 目的 / Goal

为固废 MaterialClient SQLite 补写缺失的**进场**称重，并与已有出场记录配对成完整磅单（Waybill）。

本场景：车牌 `浙MKT298`，出场皮重 `3.58t` 已在库；补进场毛重 `5.84t` @ `2026-09-01 07:42:53`，净重 `2.26t`；使用源目录 3 张监控图。

Goal 槽：`solidwaste-missing-join-pair`

Status: **active**

路径：`pipelines/graphs/materialclient/solidwaste-pair-ingest/`（见 [`pipelines/AGENTS.md`](../../../AGENTS.md)）

## 非目标

- 不修改 `repos/` 业务代码
- 不提交 `_temp/`、secrets、runs
- 不替代 OpenSpec 与 CI
- Agent 不宣布 L3 通过
- 不伪造 SolidWaste ExtraProperties / 物料行（源记录无则省略）

## 配置指针

- `./config.yaml`（`scenario.dryRun` 默认 `true`）
- `./secrets.local.yaml`（可选覆盖 database 路径）
- `./secrets.example.yaml`
- Node 工具：`./scripts/ingest-pair.ts`（`node:sqlite`）
- 源数据：`./seeds/`（`MaterialClient.db` + 3 张 jpg + `content.md`；自 `_temp/固废/91` 拷入）
- `seeds/MaterialClient.db` **不入库**（见 `seeds/.gitignore`）

## 前置

1. **Node.js 22.5+** 与 `pipelines/pnpm install`
2. `seeds/MaterialClient.db` 与 3 张 jpg 已就位（见 `seeds/README.md`）
3. 写入前将 `scenario.dryRun` 设为 `false`，或 Invoke 传 `-Write`

## Sockets

| | |
|--|--|
| Start | `sqlite-idle` |
| End | `pair-ingested` |
| Cook | `new-object` |

## Context

- 指针：本地 SQLite `WeighingRecords` / `Waybills` / `AttachmentFiles`
- 指纹：出场 `Id=14303`（可配置）、`PlateNumber=浙MKT298`、`TotalWeight=3.58`、未匹配
- 配对规则对齐 `WeighingRecord.TryMatch` + `WeighingMatchingService.CreateWaybillAsync`（收料：进>出）

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-paths]
  LocN[locate-out]
  CookN[cook-ingest]
  ValN[validate-integrity]
  GateN[Gate]
  BindN -->|"sqlite-idle"| LocN --> CookN -->|"pair-ingested"| ValN --> GateN
```

1. **bind-paths** — 解析 DB / 图片 / runs
2. **locate-out** — 定位未匹配出场
3. **cook-ingest** — 事务：进场 + 附件文件拷贝 + Waybill + 双向 Match + AttachType 升级
4. **validate-integrity** — L2 断言

失败策略：`retries: 0`；`stopOnError: true`。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：`prepare/`、`summary.json`、`report.md`。

## Invoke

```powershell
# dry-run（默认）
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/solidwaste-pair-ingest/scripts/Invoke-SolidwastePairIngest.ps1

# 实际写入
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/solidwaste-pair-ingest/scripts/Invoke-SolidwastePairIngest.ps1 -Write
```

命令：`/run-pipeline materialclient/solidwaste-pair-ingest`

## 人闸 / Gate

- `dryRun: true` 时仅预览
- `-Write` / `dryRun: false` 会改 `_temp` 库并拷贝图片到 `PhotoJianKong\`
- L3 仅用户（客户端打开磅单验图）

## 判定级别

| 级 | 谁判 |
|----|------|
| L0 DB 可达 | Agent |
| L1 出场定位 | Agent 提示 |
| L2 配对完整 | Agent 提示 |
| L3 业务正确 | **用户** |

## Handoff

Output socket：`pair-ingested`。将 `seeds/MaterialClient.db` 与 `seeds/PhotoJianKong/` 一并拷回现场客户端存储根目录后，客户端即可看到配对磅单。
