# Acceptance — deploy-urban-acceptance

Status: **agent-analyzed**（P0–P2 由 Agent 在 cook 中写出）

切流后默认 **production** profile：正式发版口径（含 Recycle；worker 可注册 GovSync；gateway **5233**、Recycle **5234**）。

发版后预期权威：[`expect/after-deploy.md`](./expect/after-deploy.md)。

| 项 | 值 |
|----|----|
| run | 见各 `runs/<ts>/acceptance.md` |
| profile | `summary.json` `deployProfile` |
| P0–P2 | 由 cook 写入；P2 须匹配 `expect/after-deploy.*` |
| 解析 | `prepare/deploy-<mode>-parse.json` |
| 宿主 / VM gateway `5233` | `externalReady` / `vmPublicPort` |
| Recycle `5234` | `recycleLive` / `recyclePublicPort` |
| 镜像数 | markers `SERVICE_IMAGES` = 8 |
| P3（用户采纳） | pending |
