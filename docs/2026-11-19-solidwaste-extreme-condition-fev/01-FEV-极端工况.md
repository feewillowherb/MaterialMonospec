# 01 FEV — 极端工况

> 环：`Unknown → Experiment → Evidence → Verdict`  
> 只回答「重量还堆在测试地磅里时，固废宿主消化完能否仍配出一条 Waybill」。不是 Capability 交付。

## 1. 问题（Unknown）

`MaterialClient.SolidWaste.exe` 已打开称重窗、地磅为测试模式、收发料为收料时，诊断口在不等待的情况下连续收到：

1. 重车吨位
2. 离磅吨位
3. 轻车吨位
4. 离磅吨位

四次 HTTP 都返回时，新称重行还没有落下。队列消化完之后，是否恰好两条称重行（先重后轻）、同一车牌、`WeighingMode = 1`，并指向同一条新 `Waybill`？

## 2. 实验（Experiment）

| 项 | 内容 |
|----|------|
| 宿主 | `scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost` |
| 诊断口 | `http://localhost:9933` |
| 队列 | 测试地磅每档约 1 秒爬坡、再保持约 3 秒，下一次 `POST` 只入队 |
| Graph | `pipelines/graphs/materialclient/fev-solidwaste-extreme-condition/` |
| 判别 | 堆积出现且顺序与 Waybill 正确 → `FEASIBLE`；堆积出现但结果不对 → `INFEASIBLE`；口不可达或爆发结束时行已经写完 → `INCONCLUSIVE` |

Cook 不改库、不改 `appsettings`、不写激活码。爆发前会先离磅并等待，使四档从离磅状态排进去。

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-extreme-condition/scripts/Invoke-FevSolidWasteExtremeCondition.ps1
```

## 3. 证据（Evidence）

| 字段 | 值 |
|------|-----|
| runId | `2026-11-19T151551` |
| result | `fail` |
| fevVerdict | `INFEASIBLE` |
| P0–P1 | `pass` |
| P2 | `fail` |
| P3 | `not-judged` |
| 不含密钥 | 是 |

观察：

- 四次 `POST /api/scale/weight` 在 16 毫秒内返回。返回时基线之后没有新称重行。
- 15:16:01 落下记录 6：`12.5` 吨，车牌 `浙A7UQA3`。离磅匹配没有对手。
- 15:16:09 落下记录 7：`1.37` 吨，`PlateNumber` 为空。离磅匹配没有对手。
- 没有新 `Waybill`。14:56 的 `2026-11-19T145552` 是同一形态：重车有车牌，轻车车牌为空。

## 4. Verdict

| Verdict | 含义 |
|---------|------|
| `FEASIBLE` | 堆积被观察到，消化后顺序与 Waybill 都正确 |
| `INFEASIBLE` | 堆积被观察到，但行数、顺序、车牌或 Waybill 不对 |
| `INCONCLUSIVE` | 证据不够：未启动、未形成堆积、称重窗未开 |

**当前 Verdict：`INFEASIBLE`（2026-11-19 15:16，runId `2026-11-19T151551`）。** P3 未判定。

## 5. 人闸

- 授权窗口出现时，激活码只由用户在窗口输入。
- 登录窗口出现时，账号由用户输入。
- P3 由用户判定。Agent 不得把 cook 的 P2 写成产品通过。
- 本实验不覆盖相机超时、数据库锁或 CPU 停顿。
