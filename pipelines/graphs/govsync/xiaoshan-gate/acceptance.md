# Acceptance — xiaoshan-gate

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | 萧山卡口 `inoutRecord/save`，`buildLicenseNo` 原值 |
| 原因 | |

### 验收提示

- L0：HTTP 有响应
- L1：JSON 含 `code`/`msg`
- L2：`code == 200`
- L3：进出记录是否可接受（未拼 `-02`、无 `dataSource`）— **仅用户**
