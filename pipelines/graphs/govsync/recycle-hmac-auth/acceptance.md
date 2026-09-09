# Acceptance — recycle-hmac-auth

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | RecycleSync HMAC → 资源化利用厂 `POST …/productTransportRecord/v1/addBatch`（空数组） |
| 原因 | |

### 验收提示

- L0：HTTP 有响应
- L1：JSON 含 `code` 和/或 `msg`
- L2：不是鉴权拒绝（HTTP/业务 401/403，或 msg 含签名/鉴权/密钥等）。空数组导致的业务校验失败仍视为 **HMAC 可用**
- L3：确认这就是现场 RecycleSync 要用的 AccessKey/SecretKey — **仅用户**
