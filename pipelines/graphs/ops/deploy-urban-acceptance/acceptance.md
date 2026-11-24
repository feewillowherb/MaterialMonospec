# Acceptance — deploy-urban-acceptance

Status: **agent-analyzed**（P0–P2 由 Agent 在 cook 中写出）

切流后默认 **production** profile：正式发版口径（含 Recycle；worker 可注册 GovSync；宿主只探针 **5233**；VM gateway **5333**、Recycle **5334**）。

发版后预期权威：[`expect/after-deploy.md`](./expect/after-deploy.md)。

| 项 | 值 |
|----|----|
| run | 见各 `runs/<ts>/acceptance.md` |
| profile | `summary.json` `deployProfile` |
| P0–P2 | 由 cook 写入；P2 须匹配 `expect/after-deploy.*` |
| 解析 | `prepare/deploy-<mode>-parse.json` |
| 宿主探针 `5233` | `summary.json` `externalReady` / `externalProbePort` |
| VM publish | `summary.json` `vmPublicPort`（默认 5333） |
| Recycle | `summary.json` `recycleLive` / `recyclePublicPort`（默认 5334） |
| 镜像数 | markers `SERVICE_IMAGES` = 8 |
| P3（用户采纳） | pending |
