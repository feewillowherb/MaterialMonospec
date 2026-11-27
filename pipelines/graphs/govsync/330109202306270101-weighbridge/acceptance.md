# Acceptance — 330109202306270101-weighbridge

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

P0–P2 对应历史 cook 标签 L0–L2。P3 只由用户判定。

| 项 | 值 |
|----|-----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | 接入码 `330109202306270101` 写入 `http://191.12.234.212:5233/Api/Post` |
| 原因 | |

### 验收提示

- P0：HTTP 有响应
- P1：JSON 含 `code`/`msg`（或 `success`）
- P2：`code == 200`，且若有 `success` 则为 true
- P3：称重记录是否可接受（车牌 `浙A12345`、重量 `1060` kg、`snapTime=2026-11-27 10:40:41`、接入码 `330109202306270101`、抓拍为 `_tmp/1127` 那张图）— **仅用户**
