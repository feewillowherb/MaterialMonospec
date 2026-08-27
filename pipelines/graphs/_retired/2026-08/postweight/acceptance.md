# Acceptance — govsync-postweight

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | 政府平台 inoutRecord/save 出站 |
| 原因 | |

### 验收提示（人读）

- L0：请求发出且有 HTTP 响应
- L1：响应可解析为含 `code`/`msg` 的 JSON
- L2：`code == 200`（与联调「操作成功」一致）
- L3：业务是否接受本次写入（车牌/对接码/重量/图片/时间）— **仅用户判定**
