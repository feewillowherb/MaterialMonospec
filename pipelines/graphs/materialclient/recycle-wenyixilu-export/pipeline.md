# recycle-wenyixilu-export（materialclient）

## 目的 / Goal

将「文一西路」现场 `MaterialClient.db` 中 **WeighingRecords / WeighingRecordAttachments / AttachmentFiles** 导出为 CSV，并在 `文一西路/2026` 下解析附件对应图片路径，供 MaterialClient.Recycle 侧数据输入与核对。

Goal 槽：`recycle-site-db-export`

Status: **active**

路径：`pipelines/graphs/materialclient/recycle-wenyixilu-export/`（见 [`pipelines/AGENTS.md`](../../../AGENTS.md)）

## 非目标

- 不导出 Waybills / WaybillAttachments / Materials / Providers
- 不修改现场原件 DB / 不修改 `repos/` 业务代码
- 不拷贝图片本体进仓库（只写解析路径）
- 不提交 secrets / runs / out
- 不替代 OpenSpec 与 CI
- Agent 不宣布 L3 通过

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（gitignore；填 `sourceDb` / `photoRoot`）
- `./secrets.example.yaml`
- Node：`./scripts/export-csv.mjs`（`node:sqlite`，experimental）
- Invoke：`./scripts/Invoke-RecycleWenyixiluExport.ps1`（experimental）

## 前置

1. **Node.js 22.5+**
2. `secrets.local.yaml` 指向现场 DB 与 `2026` 照片根目录
3. 中文路径下 Node 可能打不开 SQLite → 脚本会先拷贝到 `runs/<ts>/prepare/` ASCII 副本

## Sockets

| | |
|--|--|
| Start | `sqlite-site-raw` |
| End | `csv-with-photo-index` |
| Cook | `new-object` |

## Context

- 指针：`sourceDb` = 文一西路 `MaterialClient.db`；`photoRoot` = 文一西路 `2026`
- 指纹：表 `WeighingRecords` / `WeighingRecordAttachments` / `AttachmentFiles`；称重多为 `WeighingMode=301`
- 附件 `LocalPath` 常见 `Lpr\...`；磁盘在 `photoRoot` 下，可能多一层 `2026`

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-paths]
  CookN[cook-export]
  ValN[validate-counts]
  GateN[Gate]
  BindN -->|"sqlite-site-raw"| CookN -->|"csv-with-photo-index"| ValN --> GateN
```

1. **bind-paths** — 读 config/secrets；建 `runs/<ts>/`；拷贝 DB → `prepare/MaterialClient.db`
2. **cook-export** — 写三张 CSV；解析 `ResolvedPhotoPath` / `photoFound`
3. **validate-counts** — 行数对账 + `photo-resolve-report.json` + summary/report

失败策略：`retries: 0`；`stopOnError: true`。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | sink |
|-----------|------|
| prepare | `prepare/`（DB 工作副本） |
| csv | `csv/WeighingRecords.csv` 等 |
| photoReport | `photo-resolve-report.json` |
| summary | `summary.json` |
| report | `report.md` |

另镜像一份到 `out/latest/`（gitignore），方便人工取用。

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/recycle-wenyixilu-export/scripts/Invoke-RecycleWenyixiluExport.ps1
```

命令：`/run-pipeline materialclient/recycle-wenyixilu-export`

## 人闸 / Gate

- 缺 `sourceDb` / `photoRoot` 时停
- L3 仅用户（打开 ResolvedPhotoPath 验图）

## 判定级别

| 级 | 谁判 |
|----|------|
| L0 DB 可达 | Agent |
| L1 CSV 行数一致 | Agent 提示 |
| L2 图片索引统计 | Agent 提示 |
| L3 业务正确 | **用户** |

## Handoff

Output socket：`csv-with-photo-index`。下游若灌入 Recycle，须另开 ingest Goal，不在本图写库。
