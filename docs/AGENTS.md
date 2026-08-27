# MaterialMonospec / docs — Agent 约定

本文件**仅约束** `docs/` 下的调研笔记、说明与 walkthrough 产出。  
不约束 `openspec/`、`repos/` 中的 OpenSpec 规范与业务代码（那些仍遵守仓库根目录 `AGENTS.md`）。

BMAD 规划边界见 [`_bmad/custom/OPENSPEC-HANDOFF.md`](../_bmad/custom/OPENSPEC-HANDOFF.md)；本仓约定 `project_knowledge` 指向 `docs/`（BMAD 读知识），规划产物默认落 `_bmad-output/`。

## 与 BMAD 的结合（优先用对工具）

### 原则

1. **场景适合 BMAD 时，MUST 尽量用 BMAD skill 生成**，不要在 `docs/` 里手写一套平行的 PRD / 架构 / 产品简报 / 决策级调研仪式。
2. **`docs/` 是仓库知识与代码考古落点**；`_bmad-output/` 是 BMAD 工作流正式产物落点。二者用**单向指针**衔接，避免全文双写。
3. **实现仍走 OpenSpec**（勿用 BMAD 的 build / dev / sprint / QA / retrospective 替代 OpenSpec apply）。规划收束后：`/opsx:propose` → apply → archive。

### 场景路由（先判再写）

| 场景 | 优先 | 默认落点 | 何时才写进 `docs/` |
|------|------|----------|-------------------|
| 产品想法不明、brief / PRFAQ、头脑风暴 | BMAD（`bmad-product-brief` / `bmad-prfaq` / `bmad-brainstorming`） | `_bmad-output/planning-artifacts/` 等 | 用户要「长期可读摘要」时：日期夹里 1 页摘要 + 链到 BMAD 产物 |
| 需求成文 / 改 PRD / 校验 PRD | BMAD（`bmad-prd`） | `_bmad-output/.../prd` | 同上；**MUST NOT** 在 `docs/` 另起完整 PRD |
| 架构不变量 / 技术怎么拆才一致 | BMAD（`bmad-create-architecture`） | `_bmad-output/.../architecture` | 需要给 OpenSpec/实现对照时：短摘录或链接 |
| UX 方案（有 UI 且是主交付） | BMAD（`bmad-create-ux-design`） | planning UX 产物 | 可选链到既有产品权威文档 |
| 决策级外向调研（市场 / 领域 / 竞品 / 技术选型） | BMAD（`bmad-market-research` / `bmad-domain-research` / `bmad-technical-research`） | `_bmad-output/.../research` | 结论要进仓库知识时：蒸馏 cited 摘要进 `docs/YYYY-MM-DD-*`，原材料仍以 BMAD run 为准 |
| 子仓/本仓**代码考古**、接口摸底、既有行为 walkthrough、运维手册、管线设计笔记 | **直接 `docs/`**（不必强行套 BMAD） | `docs/YYYY-MM-DD-主题/` | — |
| 挂起项目碎片、衍生改进、先记下 / pending | **Intake** | `docs/intake/<YYYY-MM>/INT-xxx` 或 `…/drafts/` | 够种子 → INT；未想清 → draft（不占序号） |
| 已够清楚、只要 OpenSpec change | OpenSpec（`/opsx:propose`） | `openspec/changes/` | 调研夹可作输入链接；不必先空跑 PRD |
| 不确定下一步 | `bmad-help` | — | 按推荐 skill 走，勿先堆长文到 `docs/` |

不确定时：**Ask 一句**「走 BMAD 规划，还是只做代码调研进 docs？」——默认偏 BMAD（若问题像产品/架构/决策），偏 docs（若问题像「这段代码怎么工作」）。

### 优雅衔接（推荐流水线）

```text
代码/现场证据 ──► docs/YYYY-MM-DD-*（考古、证据、walkthrough）
                         │
                         ▼  （作 project_knowledge / 输入）
              BMAD brief → PRD → architecture →（可选 UX）
                         │
                         ▼
              _bmad-output/planning-artifacts/...
                         │
                         ▼  浓缩，不整份粘贴
              /opsx:propose → openspec/changes/<id>/
```

反向也成立：BMAD research / PRD 定稿后，若 Agent 日常会反复引用，**蒸馏**进 `docs/<YYYY-MM-DD>-<主题>/`：

- `00-调研总览.md`：决策、范围、**链接** `_bmad-output/...`（路径相对仓库根）
- 后续编号文件：仅放 docs 侧独有内容（代码路径表、复现步骤、与 pipelines 的对照）
- **MUST NOT** 把整份 PRD/架构无字复制进 docs

### 约束（Agent）

- 用户说「调研 / 想清楚 / 写 PRD / 做架构 / 竞品或技术选型研究」且未指定「只要 docs 笔记」时：**MUST** 先按上表选 BMAD skill（可用 `bmad-help`），再落盘。
- 在 `docs/` 新建日期调研夹前：快速自检是否其实该开 BMAD；若是，说明并改走 BMAD，而不是先写长文再补救。
- **MUST NOT** 用 `docs/` 替代 `_bmad-output` 的规划权威；**MUST NOT** 用 BMAD 实现类技能替代 OpenSpec apply。
- docs 调研可以**指向** `pipelines/`、`openspec/`、`_bmad-output/`；不得把仍在用的管线/协议只写在 docs（管线权威见 `pipelines/` 与 `docs/2026-08-13-ai-pipeline-design-philosophy/`）。

## 源码引用

本仓库源码位于 `repos/`（目录联接），调研文档中引用的路径均相对 MaterialMonospec，例如：

| 写法示例 | 含义 |
|----------|------|
| `repos/MaterialClient/src/MaterialClient.Common/...` | MaterialClient 子仓库 |
| `repos/UrbanManagement/...` | UrbanManagement 子仓库 |
| `repos/FdSoft.BasePlatform/...` | FdSoft.BasePlatform 子仓库 |
| `openspec/changes/<name>/` | 本仓库 OpenSpec 变更 |
| `_bmad-output/planning-artifacts/...` | BMAD 规划 / 决策级调研产物 |

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
- 若本夹是 BMAD 产物的蒸馏：总览 MUST 含指向 `_bmad-output/...` 的链接与蒸馏日期。

### 例外（既有文档）

以下类型**不强制**迁入 `YYYY-MM-DD-主题/` 结构，可保持现有布局：

- 运维/迁移类固定手册（如 `troubleshooting.md`、`migration-guide.md`、`monospecs-yaml-template.md`）
- 按产品域长期维护的目录（如 `UrbanManagement/`、`HikLpr/`、`SyncDoc/`、`intake/`）

**新建调研**仍应使用上文的日期文件夹格式。

## Intake 需求收件（Parking）

> 机制 topic：`intake-parking`。扩展设计见 [`docs/2026-08-27-intake-parking/`](2026-08-27-intake-parking/00-调研总览.md)。  
> **不用** `proposal-backlog` / `PBL`——避免与 OpenSpec `proposal.md` 及 Scrum Product Backlog 混淆。

### 是什么

OpenSpec / BMAD **之前**的需求种子池：挂起项目的日常碎片、以及 apply/调研中发现的超出当前 change 范围的改进。先记录、不阻塞当前变更；消化窗口可按 **theme** 收成 BMAD Epic，再切 OpenSpec change。

`docs/intake/`：正式种子为 `docs/intake/<YYYY-MM>/INT-001-<slug>.md`（登记月 + **全局序号**）；与 Agent 碎聊、尚未够格时先写 `…/<YYYY-MM>/drafts/<YYYY-MM-DD>-<slug>.md`（**不占** Next ID）。详见 [`08-draft.md`](2026-08-27-intake-parking/08-draft.md)。

### 目录结构

```
docs/intake/
├── README.md            ← 按 theme + 按月索引；Next ID
├── _template.md         ← 正式 INT
├── _draft-template.md   ← 草稿纸
├── YYYY-MM/
│   ├── README.md
│   ├── drafts/          ← 活跃 scratch
│   │   ├── YYYY-MM-DD-<slug>.md
│   │   └── archive/     ← 已 promote / discarded
│   └── INT-001-<slug>.md
└── ...
```

### 何时写 Draft vs INT

| 落点 | 时机 |
|------|------|
| **draft** | 「先记一下 / 还没想清楚 / 帮我理理」；theme 未定；半句碎片。**禁止**占用 INT 序号 |
| **INT** | 已够 1–3 句种子（theme + summary）；用户明确「收件 / 落成 INT」；apply 超出 scope 的可独立改进 |

**登记准则（INT）**：若做进当前 change 需动**当前 `proposal.md` 未列出的模块**，则登记 INT（或先 draft 再 promote）。

### 如何登记 Draft

1. 取当天日期与年月 → 确保 `docs/intake/<YYYY-MM>/drafts/`
2. 复制 `_draft-template.md` → `drafts/<YYYY-MM-DD>-<slug>.md`
3. **不**改 Next ID；可选在根 README「活跃 drafts」提及
4. 够种子后 promote：拆 1–N 条 INT → 源 draft **archive**（移入 `drafts/archive/`）或 **delete**（默认未指定时 archive）

### 如何登记 INT

1. 由 `created` 取年月 `YYYY-MM`；若无则创建 `docs/intake/<YYYY-MM>/`
2. 复制 `docs/intake/_template.md` → `<YYYY-MM>/INT-<下一序号>-<slug>.md`（序号升序，不复用）
3. 必填：`theme`、`intake_month`（与文件夹名一致）、`kind`、`summary`、`source`、`created`；挂起类填 `parked_until`（`YYYY-MM`）
4. 更新 `docs/intake/README.md` 索引、Next ID 及该月 `README.md`（若有）
5. 衍生类：在源 change 的 proposal/design 附一句「衍生见 `docs/intake/<YYYY-MM>/INT-XXX-<slug>.md`」
6. 可选 GitHub Issue：标题 `[INT-00N] …`，body 链到 INT 文件；INT 填 `github`

### 状态流转

- `open` → `triaged` → `absorbed`（已进 BMAD Epic）→ `proposed`（已有 `openspec/changes/`）→ `closed`
- **挂起月**：仅 `open` / `triaged`；禁止空占 Epic 或仅为记账 propose
- 升级时更新条目「孵化记录」与 README；**保留** INT 文件作历史
- 顶层长期维护，**不**进 `YYYY-MM-DD-主题/` 日期文件夹

### 约束

- **不**替代 BMAD / OpenSpec——种子粒度（1–3 句 + 证据链接），详细内容留给 Epic / change
- **不**在 INT / draft 写完整 PRD/design/tasks
- **不**用半截聊天占用 `INT-00N`（应先 draft）
- Agent **不应**自行升到 `absorbed` / `proposed`，除非用户明确要求消化 / `/opsx:propose`
- Agent **不应**自行把 draft promote 为 INT，除非用户明确要求收件 / 落成 INT（或用户确认「已够种子」）

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
