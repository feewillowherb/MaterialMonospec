# Acceptance — urban-license-probe

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | MaterialClient.Urban pipeline Local license seed + 启动授权 |
| seed | `_shared/urban/seeds/demo-license.json`（默认） |
| 原因 | |

### 验收提示

- L0：`GET /` 返回 200
- L1：`GET /api/settings` 返回 200（已过启动授权门）
- L2：`prepare/license-seed.json` 显示 `seedSkipped=false` 且 `license.urban` 存在
- L3：Urban 主窗口正常、无「软件未授权」阻断 — **仅用户**
