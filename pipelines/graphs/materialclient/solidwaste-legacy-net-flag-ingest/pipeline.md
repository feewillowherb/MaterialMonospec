# solidwaste-legacy-net-flag-ingest（materialclient）

## 目的 / Goal

为指定固废 Waybill 写入 ExtraProperties  
`SolidWasteInfo.UseIndependentDisplayedNet = true`，启用旧版「净重独立 F2」显示（可 `8.28 − 6.22 → 2.07`）。

Goal 槽：`solidwaste-legacy-independent-net-flag`  
路径：`pipelines/graphs/materialclient/solidwaste-legacy-net-flag-ingest/`

样例 3 条（见 `_tmp/117/old-mode-data.txt` / `config.yaml` `scenario.targets`）：

| 车牌 | 进场 | 出场 |
|------|------|------|
| 浙A26E23 | 2026-11-04 07:51:17 | 2026-11-04 07:54:33 |
| 浙A68L08 | 2026-11-04 09:31:57 | 2026-11-04 09:34:31 |
| 浙A68L08 | 2026-11-04 10:27:49 | 2026-11-04 10:36:04 |

## 非目标

- 不改 `repos/` 业务代码（产品开关见 OpenSpec `add-solidwaste-independent-net-display-flag`）
- 不批量打标其它运单
- Agent 不宣布 P3 / 产品通过

## 配置

- `./config.yaml` — `target.databaseRel` 默认 `_tmp/117/MaterialClient.db`；`scenario.dryRun: true`
- `./secrets.local.yaml`（可选）覆盖 `databasePath`
- Node：`./scripts/set-independent-net-flag.ts`（`node:sqlite`）

## 前置

1. Node 22.5+；`pipelines/` 下 `pnpm install`（tsx）
2. 目标库存在且含 `Waybills.ExtraProperties`（ABP 扁平 JSON）
3. 客户端已含读该 ExtraProperties 的代码后再验收 UI

## Cook

1. **bind-paths** — DB / runs  
2. **locate-waybills** — 车牌 + Join/Out 秒级前缀各命中 1 行  
3. **cook-flag** — 合并 JSON 键；默认 dryRun  
4. **validate** — write 后重读断言

## Invoke

```powershell
# dry-run（默认）
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/solidwaste-legacy-net-flag-ingest/scripts/Invoke-SolidwasteLegacyNetFlag.ps1

# 实际写入
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/materialclient/solidwaste-legacy-net-flag-ingest/scripts/Invoke-SolidwasteLegacyNetFlag.ps1 -Write
```

## 判定

| 级 | 含义 |
|----|------|
| P0 / L0 | DB 可开 |
| P1 / L1 | 3 条全部唯一定位 |
| P2 / L2 | write 后 ExtraProperties 含标志 |
| P3 / L3 | 用户确认屏/导出/票为独立净重 |

## Handoff

Output：`flag-written`。将改过的 `MaterialClient.db` 拷回现场存储根后，客户端按 OpenSpec 开关读标志。
