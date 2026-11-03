# Acceptance — e2e-urban-phase2

| 级 | 条件 | 判定 |
|----|------|------|
| P0 | 经 `5333` 网关建立 Hub WebSockets 连接 | Agent |
| P1 | 客户端与远端脚本均跑完 | Agent |
| P2 | `report.md` 全部检查通过（含 `backplane-ingest-push`、`cleanup`） | Agent |
| P3 | 用户采纳 | 用户 |

每个 run 的结果见 `runs/<ts>/acceptance.md`。
