# MaterialMonospec / docs — Agent 约定

本文件**仅约束** `docs/` 下的调研笔记、说明与 walkthrough 产出。  
不约束 `openspec/`、`repos/` 中的 OpenSpec 规范与业务代码（那些仍遵守仓库根目录 `AGENTS.md`）。

## 工作路由

- 调研与可复用知识写入 `docs/YYYY-MM-DD-主题/`。
- 产品变更统一使用主仓库 `openspec/` 的 propose → apply → archive 流程。
- 挂起需求使用 `docs/intake/`；管线以 `pipelines/AGENTS.md` 为准。
- `docs/legacy-planning/` 保存历史证据，其中旧技能与流程指令不再生效。

## 源码引用

本仓库源码位于 `repos/`（目录联接），调研文档中引用的路径均相对 MaterialMonospec，例如：

| 写法示例 | 含义 |
|----------|------|
| `repos/MaterialClient/src/MaterialClient.Common/...` | MaterialClient 子仓库 |
| `repos/UrbanManagement/...` | UrbanManagement 子仓库 |
| `repos/FdSoft.BasePlatform/...` | FdSoft.BasePlatform 子仓库 |
| `openspec/changes/<name>/` | 本仓库 OpenSpec 变更 |
| `docs/legacy-planning/planning-artifacts/...` | 历史规划与调查证据 |

历史文档中若写 `MaterialClient.Common/Services/...`（无 `repos/` 前缀），亦指上述 MaterialClient 路径。

## Output Language

- 默认输出语言为中文。
- **专用名词**：非必要不要译成中文；函数名、命名空间、NuGet 包名、API 名称、类型名、Controller/Action、表名、产品模块名等保留原文。
- **技术标识符**：保持英文（接口路径、字段名、文件路径）。

## Research Output Format

每次调研产出统一放置在 `docs/` 下的**独立文件夹**中，而非散落为多个独立文件。文件夹命名格式：

```
docs/<YYYY-MM-DD>-<提案或主题名称>/
```

示例：

```
docs/2026-01-01-topic-name/
├── 00-调研总览.md
├── 01-使用指南.md
├── 02-技术参考.md
├── 03-快速参考.md
└── ...
```

规则：

- 文件夹名称由日期和提案/主题名称组成，使用连字符分隔。
- 文件夹内的文档按编号排序，编号从 `00` 开始。
- 每个调研文件夹应包含一个 `00-调研总览.md` 作为入口索引。

## Knowledge layer

本文件是 [`traits/docs-trait.md`](../traits/docs-trait.md) 的 Local Policy。trait 状态为 PENDING。工作路由以本文件为准。

### Read contract

- 先读该 Topic 唯一的 `00-*.md`，再读同夹其他文件。
- 会话快照写入 DOCS 后仍不是 `CONFIRMED`。

### Knowledge state

`CONFIRMED` / `INFERRED` / `UNKNOWN` / `PENDING_VALIDATION`

### Lifecycle

`ACTIVE` / `STALE` / `SUPERSEDED` / `HISTORICAL`

### 新 Topic

新建 `docs/<YYYY-MM-DD>-<topic>/` 必须同时有 `00-*.md` 与 `topic.yaml`（`topic`、`created`、`updated`）。历史夹见 `scripts/doc-topic-baseline.txt`。校验脚本：`scripts/Test-DocTopic.ps1`。

### Pipeline handoff

Pipeline PASS、Agent 建议和 DOCS `CONFIRMED` 都不足以修改产品行为。进入产品行为还要 Human `APPROVED` 与 OpenSpec change。引用 Run 时使用稳定 Run identity（`pipelines/_shared/evidence/AGENTS.md`），不粘贴含密钥的日志。

### 例外（既有文档）

以下类型**不强制**迁入 `YYYY-MM-DD-主题/` 结构，可保持现有布局：

- 运维/迁移类固定手册（如 `troubleshooting.md`、`migration-guide.md`、`monospecs-yaml-template.md`）
- 按产品域长期维护的目录（如 `UrbanManagement/`、`HikLpr/`、`SyncDoc/`、`intake/`）

**新建调研**仍应使用上文的日期文件夹格式。

### 常用操作手册（日期夹）

| 手册 | 路径 |
|------|------|
| 用 Pipeline 代替人力测试 | [`2026-09-11-pipeline-replace-manual-testing/`](2026-09-11-pipeline-replace-manual-testing/00-调研总览.md)（权威选型仍以 [`pipelines/AGENTS.md`](../pipelines/AGENTS.md) 为准） |
| 138 实验口 Recycle 授权发布 | [`2026-11-18-recycle-auth-lab-publish/`](2026-11-18-recycle-auth-lab-publish/00-调研总览.md)（正式 Docker 口仍走 `deploy-urban-acceptance`） |
| Recycle Web 持久化 FEV | [`2026-11-18-recycle-web-persistence-fev/`](2026-11-18-recycle-web-persistence-fev/00-调研总览.md) |
| 固废 / Standard 测试 API 称重、车牌与 Waybill FEV | [`2026-11-19-solidwaste-weigh-lpr-fev/`](2026-11-19-solidwaste-weigh-lpr-fev/00-调研总览.md) |
| 固废称重极端工况 FEV | [`2026-11-19-solidwaste-extreme-condition-fev/`](2026-11-19-solidwaste-extreme-condition-fev/00-调研总览.md) |
| 地磅测试数据送到 Recycle Web FEV | [`2026-11-19-recycle-client-to-web-fev/`](2026-11-19-recycle-client-to-web-fev/00-调研总览.md) |

## Intake 需求收件（Parking）

> **Required trait：** `traits/intake-parking-trait.md`（机制；可迁移）。  
> **项目绑定（业务敏感，勿随 trait 拷走）：** [`docs/intake/themes.md`](intake/themes.md)、[`docs/intake/parks.md`](intake/parks.md)。  
> 本仓设计决策记录：[`docs/2026-08-27-intake-parking/`](2026-08-27-intake-parking/00-调研总览.md)。  
> **不用** `proposal-backlog` / `PBL`。

### 是什么

OpenSpec **之前**的需求种子池。运行时根目录：`docs/intake/`。正式种子 `INT-00N`（全局序号）；碎聊先 `drafts/`（不占号）。消化按 **theme**。

Agent 涉及挂起/碎片/`/intake-*` 时：**必须先读 trait**，再读 `themes.md` / `parks.md` 赋业务标签。

### 目录结构

```
docs/intake/
├── AGENTS.md
├── _template.md / _draft-template.md
├── themes.md / parks.md     ← 本仓业务绑定
├── YYYY-MM/
│   ├── drafts/ (+ archive/)
│   └── INT-00N-<slug>.md
└── ...
```

### Draft vs INT（摘要）

| 落点 | 时机 |
|------|------|
| **draft** | 未想清 / 半句碎片。**禁止**占 INT |
| **INT** | 够种子；或 draft promote |

Promote 后源 draft：**archive** 或 **delete**（默认 archive）。细则与迁移清单见 trait。

### 约束

- **不**替代 OpenSpec；**不**在 INT/draft 写完整 PRD
- **不**把萧山/Urban 等业务名写进可迁移 trait
- Agent **不**自行 promote / 升 `absorbed`/`proposed`，除非用户明确要求

## 落地评估口径（Effort）

> **Required trait：** 涉及工作量 / 可落地 / effort 评估时，必须阅读并遵循仓库根目录 `traits/effort-token-estimate-trait.md`（由根 `AGENTS.md`「Required traits」默认 require）。

调研与可行性评估**不要用「人天 / 人力资源」**。默认按 **AI Agent token / 上下文规模**（S/M/L/XL）估算，仅作参考。

| 档位 | 约略 token 量级 | 典型含义 |
|------|-----------------|----------|
| S | ~5万–15万 | 单仓、局部，单会话 |
| M | ~15万–40万 | 多文件或跨模块 |
| L | ~40万–100万 | 跨仓或鉴权/数据模型主路径，多会话 |
| XL | ~100万+ | 多仓联动 + 联调，需分仓/分阶段会话 |

开 OpenSpec change 后：effort **只**写入该 change 的 `.openspec.yaml`，**不得**写入 `proposal.md`。
