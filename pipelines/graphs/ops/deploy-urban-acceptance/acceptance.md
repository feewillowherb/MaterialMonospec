# Acceptance — deploy-urban-acceptance

Status: **agent-analyzed**（P0–P2 由 Agent 在 cook 中写出）

切流后默认 **production** profile：正式发版口径（worker 可注册 GovSync；宿主只探针 **5233**；VM 内仍监听 5333）。

| 项 | 值 |
|----|----|
| run | 见各 `runs/<ts>/acceptance.md` |
| profile | `summary.json` `deployProfile` |
| P0–P2 | 由 cook 写入 |
| 解析 | `prepare/deploy-<mode>-parse.json` |
| 宿主探针 `5233` | `summary.json` `externalReady` / `externalProbePort` |
| VM publish | `summary.json` `vmPublicPort`（默认 5333，非宿主口） |
| P3（用户采纳） | pending |
