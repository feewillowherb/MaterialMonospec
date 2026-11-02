# DOCS — reusable project knowledge

## Metadata

```yaml
trait:
  id: docs
  version: "0.1.0"
  date: "2026-11-02"
  status: PENDING
  type: Knowledge Layer
```

来源 DOCS 仍为 PENDING。本仓文件保持 PENDING，不得标成 Established。目录细则以 `docs/AGENTS.md` 为 Local Policy。

## Core

DOCS 保存可再次发现、可引用的项目知识。它不是第二套规格、验收记录或 Epic 状态库。

## Authority

| 信息 | 权威 |
|------|------|
| 产品 SHALL / change | `openspec/` |
| 可行性 Verdict | FEV |
| Capability Acceptance | ICD |
| Epic STOP / Defer | CED |
| 当前程序行为 | 源码 / 运行 / 测试 |
| cook 结果 | `pipelines/` |
| 无更明确归属、但会再被引用的知识 | `docs/` |

DOCS 可以摘要和链接上述结论，不得因复制而改变原权威。

## Read contract

1. 先读该 Topic 唯一的 `00-*.md`。
2. 再按需读同夹其他编号文件。
3. 会话里的临时结论写入 DOCS 后仍不是 `CONFIRMED`，除非证据与状态已经更新。

## Knowledge state

| 状态 | 含义 |
|------|------|
| `CONFIRMED` | 有可追溯证据，且与当前源码或运行结果一致 |
| `INFERRED` | 由证据归纳，尚未被再次核对 |
| `UNKNOWN` | 还没有足够证据 |
| `PENDING_VALIDATION` | 已有候选结论，等待指定核对 |

## Lifecycle

`ACTIVE` / `STALE` / `SUPERSEDED` / `HISTORICAL`

被替代的 Topic 标明继任路径，不把旧文改写成新结论。

## Topic file

新建 `docs/<YYYY-MM-DD>-<topic>/` 必须包含：

- `00-*.md`
- `topic.yaml`，字段为 `topic`、`created`、`updated`

历史夹按 `scripts/doc-topic-baseline.txt` 豁免，触达时再补。

## Pipeline handoff

Pipeline PASS、Agent 建议或 DOCS `CONFIRMED` 都不得代替 Human `APPROVED` 去修改产品行为。DOCS 引用 Run 时使用稳定 Run identity，不粘贴含密钥的日志。
