# scripts

仓库根 `scripts/` 是校验、构建和发布入口。Graph 自己的 cook 脚本留在 `pipelines/graphs/<domain>/<slug>/scripts/`。

| 位置 | 职责 |
|------|------|
| `scripts/` | 配置校验、迁移校验、文档 Topic 校验、子仓构建与发布 |
| `pipelines/graphs/**/scripts/` | 该 Graph 的 cook / invoke。实验性脚本仍标在 Graph 内 |
| `pipelines/_shared/` | 跨 Graph 复用的 Node cook 与证据清单约定 |

根脚本不得把产品行为改写塞进校验脚本。Graph cook 的语言选型以 `pipelines/AGENTS.md` §4 为准。

## Topic 校验

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Test-DocTopic.ps1
```

新建日期调研夹必须有 `topic.yaml` 与 `00-*.md`。`scripts/doc-topic-baseline.txt` 中的历史夹豁免，直到该夹被补齐。
