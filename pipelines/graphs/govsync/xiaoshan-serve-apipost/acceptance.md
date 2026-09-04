# Acceptance — xiaoshan-serve-apipost

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | XiaoShanServe `POST /Api/Post`（`mGovRequestWeight` → UM Legacy） |
| 原因 | |

### 验收提示

- L0：HTTP 有响应
- L1：JSON 含 `success` 和/或 `code`/`msg`
- L2：`code == 200`（若有 `success` 则为 true）
- L3：UM 出现 `UrbanWeighingRecord`（`IngestSource=Legacy`）或拒收表合理 — **仅用户**
