# Acceptance — urban-passage-probe

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | MaterialClient.Urban 卡口/成品本地进出（10 条 test-passage） |
| 夹具 | govsync/xiaoshan-gate/fixtures/test_pic.jpg |
| LPR seed | replace-all via seeds/lpr-devices.json |
| 原因 | |

### 验收提示

- L0：`GET /` 与 `GET /api/settings` 返回 200
- L1：`POST /api/settings` 成功，含 gate-in/out、product-in/out 四行 LPR
- L2：10 条 `POST /api/lpr/test-passage` 均 `success=true`、`published=true`
- L3：Urban 客户端卡口/成品 tab 可见对应记录 — **仅用户**
