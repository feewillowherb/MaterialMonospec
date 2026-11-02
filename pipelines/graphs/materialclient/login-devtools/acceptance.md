# Acceptance — materialclient/login-devtools

Status: **pending**

刻度为 Pipeline **P0–P3**。`config.yaml` 的 `expect.level` L0–L2 仍供现有 cook 读取，分别对应 P0–P2。旧的「仅用户 L3」对应 P3。Agent 不得把 P 级写成 ICD 等级，也不得把本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | MaterialClient LoginWindow（avalonia_devtools） |
| 原因 | |

### 验收提示（人读）

- P0：attach-to-app 成功并定位 LoginWindow / ViewModel
- P1：Username/Password 已写入且 LoginCommand 已触发
- P2：`IsLoginSuccessful` 或主称重窗出现，无持续错误文案
- P3：该账号业务是否可接受 — **仅用户判定**
