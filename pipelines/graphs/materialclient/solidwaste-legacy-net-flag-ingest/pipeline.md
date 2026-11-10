# solidwaste-legacy-net-flag-ingest（materialclient）

## 目的 / Goal

为指定固废 Waybill 写入 ExtraProperties  
`SolidWasteInfo.UseIndependentDisplayedNet = true`，启用旧版「净重独立 F2」显示（可 `8.28 − 6.22 → 2.07`）。

Goal 槽：`solidwaste-legacy-independent-net-flag`  
路径：`pipelines/graphs/materialclient/solidwaste-legacy-net-flag-ingest/`

样例 8 条（`config.yaml` `scenario.targets`；库 `_tmp/1110/MaterialClient.db`）。清单净重为 `Round(OrderGoodsWeight, 2)`，进场日是 2026-11-03：

| 车牌 | 清单净重 | 进场 | 出场 |
|------|----------|------|------|
| 浙A06L07 | 4.67 | 2026-11-03 08:22:24 | 2026-11-03 08:26:33 |
| 浙A20B28 | 3.15 | 2026-11-03 08:32:38 | 2026-11-03 08:37:37 |
| 浙A68L08 | 4.08 | 2026-11-03 09:03:25 | 2026-11-03 09:06:38 |
| 浙A26E23 | 4.04 | 2026-11-03 11:18:04 | 2026-11-03 11:20:47 |
| 浙A67E60 | 7.24 | 2026-11-03 13:14:53 | 2026-11-03 13:22:55 |
| 浙A06L07 | 7.64 | 2026-11-03 13:38:39 | 2026-11-03 13:42:22 |
| 浙A69G26 | 11.78 | 2026-11-03 14:33:28 | 2026-11-03 14:37:49 |
| 浙A53R8T | 2.98 | 2026-11-03 14:29:30 | 2026-11-03 14:38:51 |

## 非目标

- 不改 `repos/` 业务代码（产品开关见 OpenSpec `add-solidwaste-independent-net-display-flag`）
- 不批量打标其它运单
- Agent 不宣布 P3 / 产品通过

## 配置

- `./config.yaml` — `target.databaseRel` 默认 `_tmp/1110/MaterialClient.db`；`scenario.dryRun: true`
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
| P1 / L1 | 8 条全部唯一定位 |
| P2 / L2 | write 后 ExtraProperties 含标志 |
| P3 / L3 | 用户确认屏/导出/票为独立净重 |

## Handoff

Output：`flag-written`。将改过的 `MaterialClient.db` 拷回现场存储根后，客户端按 OpenSpec 开关读标志。
