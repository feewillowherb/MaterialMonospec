# traits — Agent 行为契约索引

本目录是 MaterialMonospec **编排仓**的 Agent 行为 traits。人与 Agent 的目录入口均为本文件；**MUST NOT** 使用 `README.md`（见 `agents-md-only-trait.md`）。

与根 `AGENTS.md`「Required traits」冲突时以**更严格**者为准。涉及对应场景时 **MUST** 先读该 trait 全文再动手。

## 编排仓专用（勿同步到子仓 C# traits 副本）

| Trait | 文件 | 何时强制 |
|-------|------|----------|
| agents-md-only | `agents-md-only-trait.md` | 新建/改写目录说明、脚手架、pipeline / openspec / traits / docs 索引 |
| openspec-git-workflow | `openspec-git-workflow.md` | OpenSpec Propose / Apply / Archive；跨仓同名分支、squash、`dev-*` promote |
| effort-token-estimate | `effort-token-estimate-trait.md` | 调研工作量；change `.openspec.yaml` 的 `effort:` |
| intake-parking | `intake-parking-trait.md` | 挂起/碎片需求；`/intake-draft` · register · promote |

## 跨子仓编码 / UI 约定

| Trait | 文件 | 何时强制 |
|-------|------|----------|
| avalonia-docs | `avalonia-docs-trait.md` | Avalonia UI / AXAML；`repos/MaterialClient` 界面 |
| type-owned-methods | `type-owned-methods-trait.md` | C# 变更与投影；禁止 Service 字段赋值 / mapper |
| minimal-di | `minimal-di-trait.md` | 新建类型 / DI；纯逻辑不得注册 |
| no-database-fk | `no-database-fk-trait.md` | 实体 / Fluent / SQL；禁止引擎外键 |
| viewmodel-no-repository | `viewmodel-no-repository-trait.md` | 界面层禁止 Repository / DbContext |

## 其它（按需，非默认 Required 表项）

| Trait | 文件 | 说明 |
|-------|------|------|
| standard-words | `standard-words-trait.md` | 标准用语 |
| guess-governance | `guess-governance-trait.md` | 猜测治理 |

## 非目标

- 不在此目录落盘 `README.md`
- 不把编排仓专用 trait 复制进 `repos/*/traits/`
