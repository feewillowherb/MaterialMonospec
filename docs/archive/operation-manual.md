# MaterialMonospec 操作手册

> 基于 BMAD-METHOD + OpenSpec + Cursor 三工具分工方法论，面向 MaterialMonospec 项目的完整操作指南。

**版本**: 1.0
**最后更新**: 2026-05-20
**适用项目**: MaterialMonospec（MaterialClient + UrbanManagement）

---

## 目录

- [1. 概述](#1-概述)
- [2. 环境准备与安装](#2-环境准备与安装)
- [3. 三工具分工原则](#3-三工具分工原则)
- [4. BMAD 规划阶段操作](#4-bmad-规划阶段操作)
- [5. 用户衔接操作](#5-用户衔接操作)
- [6. OpenSpec 执行阶段操作](#6-openspec-执行阶段操作)
- [7. 完整端到端流程示例](#7-完整端到端流程示例)
- [8. 跨仓库变更操作](#8-跨仓库变更操作)
- [9. 制品格式规范](#9-制品格式规范)
- [10. 故障排查](#10-故障排查)
- [11. 反模式警告](#11-反模式警告)
- [12. 快速参考卡](#12-快速参考卡)

---

## 1. 概述

### 1.1 方法论简介

MaterialMonospec 项目采用 **BMAD-METHOD + OpenSpec + Cursor** 三工具分工的开发方法论：

```
Epic 需求
    │
    ▼
┌─────────────────────────────────────────┐
│  阶段 A：Cursor + BMAD                    │
│  （Analysis → Planning → Solutioning）    │
│  产出：PRD / 架构 / 多份 proposal 草稿    │
│        可选 design 概要、project-context   │
│  禁止：tasks、Story 实施清单、sprint 驱动   │
└─────────────────────────────────────────┘
    │
    ▼  【用户手工衔接】
    │  每个 proposal → 目标项目 openspec/changes/<id>/
    │  附上 BMAD design 作为 apply 参考
    ▼
┌─────────────────────────────────────────┐
│  阶段 B：Cursor + OpenSpec                │
│  （每个 change 独立执行）                  │
│  /opsx:propose → specs → design → tasks  │
│  /opsx:apply → /opsx:archive             │
└─────────────────────────────────────────┘
```

### 1.2 角色分工一览

| 工具 | 角色 | 阶段 | 产出 |
|------|------|------|------|
| **BMAD-METHOD** | Epic 规划、架构设计、跨项目拆分 | 规划与方案 | proposal 草稿、概要 design |
| **用户** | 将 BMAD 产出导入 OpenSpec change | 衔接层 | 手工操作 |
| **OpenSpec** | 单 change 的 specs、tasks、实现与归档 | 执行与交付 | 完整变更制品 |
| **Cursor** | 统一 IDE：承载 BMAD skills 与 OpenSpec 命令 | 全程 | — |

### 1.3 项目上下文

MaterialMonospec 是一个 **Monospec 主仓库**，统一管理两个子仓库：

| 子仓库 | 类型 | 技术栈 | 用途 |
|--------|------|--------|------|
| **MaterialClient** | 桌面应用 | C# 13 / .NET 10.0 / Avalonia UI 11.3.9 / ReactiveUI / ABP / SQLite | 工业材料称重管理 |
| **UrbanManagement** | Web 应用 | ABP Framework / .NET | 城市管理 |

> **关键约束**：所有 OpenSpec 工件**必须且只能**在 MaterialMonospec 主仓库的 `openspec/` 目录中创建和管理，禁止在 `repos/` 子项目中操作。

---

## 2. 环境准备与安装

### 2.1 前置条件

| 依赖 | 最低版本 | 用途 |
|------|----------|------|
| Node.js | ≥ 20.12 | BMAD 与 OpenSpec 运行环境 |
| Python | ≥ 3.10 | BMAD 辅助工具 |
| [uv](https://docs.astral.sh/uv/) | 最新 | Python 包管理 |
| Cursor | 最新 | 统一 IDE |
| Git | 最新 | 版本控制 |

### 2.2 安装 BMAD-METHOD

在 **MaterialMonospec 主仓库根目录**执行：

```bash
# 交互式安装
npx bmad-method install --modules bmm --tools cursor

# 非交互式安装
npx bmad-method install --directory . --modules bmm --tools cursor --yes
```

安装完成后验证：

```bash
# 检查 skills 目录
ls .agents/skills/bmad-*/SKILL.md

# 预期看到多个 bmad-* skill 目录
```

BMAD skills 安装位置：

| 范围 | 路径 |
|------|------|
| 项目内 | `.agents/skills/<skill-name>/` |
| 用户全局（可选） | `~/.agents/skills/` |

### 2.3 安装 OpenSpec

```bash
# 全局安装 OpenSpec CLI
npm install -g @fission-ai/openspec@latest

# 在主仓库中初始化（如果尚未初始化）
openspec init
```

验证安装：

```bash
openspec list           # 查看活动变更
openspec list --specs   # 查看所有 specs
```

### 2.4 配置项目规则

在 `AGENTS.md` 或 `.cursor/rules` 中添加以下内容（已包含在本项目 `AGENTS.md` 中）：

```markdown
## BMAD-METHOD（规划阶段）

- 本仓库已安装 BMAD，skills 位于 `.agents/skills/`。
- Epic 级规划使用 BMAD：PRD、架构、Epic 拆分为多个 OpenSpec proposal 草稿。
- **禁止**在本流程中使用 BMAD Phase 4（`bmad-dev-story`、`bmad-sprint-planning`、
  `bmad-create-story` 等）生成任务清单；实施任务由 OpenSpec `tasks.md` 独占。
- 需要指引时优先调用 `bmad-help`。
```

### 2.5 项目目录结构

```
MaterialMonospec/
├── openspec/
│   ├── changes/                    # 活动变更
│   │   └── <change-name>/         # 变更目录
│   │       ├── proposal.md
│   │       ├── design.md
│   │       ├── specs/
│   │       └── tasks.md
│   ├── changes/archive/            # 归档变更
│   └── specs/                      # 规范定义
├── repos/                          # 子仓库（目录联接）
│   ├── MaterialClient/             # Avalonia 桌面应用
│   └── UrbanManagement/            # ABP Web 应用
├── _bmad/                          # BMAD 配置
├── _bmad-output/                   # BMAD 规划产出
│   ├── planning-artifacts/         # 规划制品
│   └── implementation-artifacts/   # 实施制品
├── .agents/skills/                 # Cursor BMAD skills
├── docs/                           # 文档
├── scripts/                        # 工具脚本
├── monospecs.yaml                  # Monospec 配置
├── PROPOSAL_DESIGN_GUIDELINES.md   # 提案设计指南
└── AGENTS.md                       # Agent 行为准则
```

---

## 3. 三工具分工原则

### 3.1 核心原则

| # | 原则 | 说明 |
|---|------|------|
| 1 | **用户自己衔接** | BMAD 不自动调用 OpenSpec；用户手动将 BMAD 产出的 proposal 导入 OpenSpec |
| 2 | **任务清单归 OpenSpec** | BMAD **不得**产出 `tasks.md`、Story 任务列表、sprint 级实施清单；`tasks.md` 仅由 OpenSpec 维护 |
| 3 | **BMAD 专注「想清再做」** | PRD、架构、Epic 拆分、跨仓库概要设计、`project-context.md`；**跳过** BMAD Phase 4 Implementation |
| 4 | **Cursor 双栈** | 同一工作区安装 BMAD skills（`.agents/skills/`）与 OpenSpec（`openspec init` 生成的 skills/命令） |

### 3.2 职责边界矩阵

| 维度 | BMAD-METHOD | 用户 | OpenSpec |
|------|-------------|------|----------|
| Epic / PRD | ✅ 产出 | 审阅、定稿 | ❌ |
| 拆分为多个可交付单元 | ✅ 多个 proposal 草稿 | 选择命名、排序、取舍 | ❌ |
| 跨前端/后端/多仓库架构 | ✅ architecture + 概要 design | 确认边界与依赖 | 单 change 内细化 design |
| `proposal.md` | ✅ 草稿（规划侧） | 复制到目标项目 / 触发 propose | ✅ 正式 change 内版本 |
| `design.md` | ✅ 概要（关键决策） | 作为 apply 参考传入 | ✅ 可扩展为 change 内 design |
| `specs/` delta | ❌ | — | ✅ |
| **`tasks.md`** | **❌ 禁止** | — | **✅ 唯一来源** |
| 代码实现 | ❌（不用 dev-story） | 验收 | ✅ `/opsx:apply` |
| 归档 | ❌ | — | ✅ `/opsx:archive` |

---

## 4. BMAD 规划阶段操作

### 4.1 阶段总览

BMAD 采用四阶段生命周期，**本项目中仅使用 Phase 1–3**：

```
Phase 1（可选）     Phase 2（必须）     Phase 3（必须）
Analysis       →   Planning        →   Solutioning
头脑风暴            PRD                架构设计
市场调研            需求文档            Epic 拆分
技术调研            UX 设计            就绪检查
```

> **Phase 4（Implementation）由 OpenSpec 接管，不使用 BMAD 实施工作流。**

### 4.2 获取指引：bmad-help

在 Cursor 对话中：

```
使用 bmad-help，我刚完成架构，下一步做什么？
```

`bmad-help` 会根据当前阶段给出下一步建议，并在规划完成后提示用户转入 OpenSpec。

### 4.3 Phase 1：Analysis（可选）

适用于：新项目、不确定的需求、需要验证的想法。

| Skill | 用途 | 何时使用 |
|-------|------|----------|
| `bmad-brainstorming` | 引导式头脑风暴 | 需要创意发散 |
| `bmad-market-research` | 市场调研和验证 | 商业决策前验证 |
| `bmad-domain-research` | 领域知识研究 | 进入新业务领域 |
| `bmad-technical-research` | 技术可行性调研 | 技术选型评估 |
| `bmad-product-brief` | 产品简报 | 产品愿景定义 |
| `bmad-prfaq` | Working Backwards 压力测试 | 从客户视角反推产品 |

**操作示例**：

```
加载 bmad-brainstorming skill，围绕 MaterialClient 的无人值守称重功能进行头脑风暴。
```

### 4.4 Phase 2：Planning

#### 4.4.1 创建 PRD

```
加载 bmad-create-prd skill，基于以下需求创建 PRD：
- MaterialClient 需要增加批量称重功能
- 支持多人排队称重
- 自动生成称重报告
```

BMAD PRD 工作流支持三种意图：

| 意图 | 说明 |
|------|------|
| **Create** | 从零创建 PRD |
| **Update** | 基于现有 PRD 增量修改 |
| **Validate** | 验证 PRD 质量 |

#### 4.4.2 UX 设计（可选）

```
加载 bmad-create-ux-design skill，基于当前 PRD 创建 UX 设计规范。
```

产出纳入 design 或 OpenSpec design 参考。

### 4.5 Phase 3：Solutioning

#### 4.5.1 架构设计

```
加载 bmad-create-architecture skill，基于当前 PRD 和 UX 设计，
为 MaterialClient 批量称重功能做架构设计。
需要考虑：
- 与现有称重服务的集成
- 数据库 schema 变更
- 前后端交互方式
```

**多项目/前后端**：在架构中明确：
- 系统边界（MaterialClient 桌面端、后端 API）
- 共享契约（API 接口、数据模型）
- 各 slice 落在哪个 repo

#### 4.5.2 Epic 拆分为多个 proposal 切片

**关键操作**——使用 BMAD 将 Epic 拆分为多个可独立归档的 OpenSpec change：

```
bmad-help，把这个 Epic 拆成 N 个可独立交付的 OpenSpec change。
每个 slice 只输出 proposal.md（Why / What Changes / Capabilities / Impact）
和概要 design.md（Context / Goals / Decisions）。
不要生成 tasks、Story 卡片、冲刺计划或开发步骤列表。
```

**推荐产出目录结构**：

```
_bmad-output/planning-artifacts/<epic-slug>/
├── project-context.md          # 可选，跨 change 的实现约束
├── architecture.md             # 可选，架构产出
├── slices/
│   ├── 01-batch-weighing-api/
│   │   ├── proposal.md         # OpenSpec propose 输入草稿
│   │   └── design.md           # 概要设计
│   ├── 02-batch-weighing-ui/
│   │   ├── proposal.md
│   │   └── design.md
│   └── 03-weighing-report/
│       ├── proposal.md
│       └── design.md
└── epic-traceability.md        # 可选：slice ↔ 能力映射
```

#### 4.5.3 就绪检查

```
加载 bmad-check-implementation-readiness skill，
检查当前规划是否已准备好交给 OpenSpec 执行。
```

确认可交给 OpenSpec 后，用户进入衔接阶段。

#### 4.5.4 生成项目上下文（可选）

```
加载 bmad-generate-project-context skill，生成本 Epic 的 project-context.md。
```

供 OpenSpec apply 时保持一致性。

### 4.6 BMAD 推荐使用的 Skills 一览

| Skill | 用途 | OpenSpec 衔接 |
|-------|------|---------------|
| `bmad-help` | 下一步指引 | 规划完成后提示转入 OpenSpec |
| `bmad-brainstorming` / `bmad-product-brief` | 想法澄清（可选） | 产出纳入 PRD 背景 |
| `bmad-create-prd` | PRD | 作为多个 proposal 的上游依据 |
| `bmad-create-ux-design` | UX 概要 | 写入 design 或 OpenSpec design 参考 |
| `bmad-create-architecture` | 技术架构、ADR | 产出 `design.md` 概要，**不写 tasks** |
| `bmad-create-epics-and-stories` | Epic → proposal 切片 | 每个切片输出 `proposal.md` 草稿 |
| `bmad-check-implementation-readiness` | 就绪检查 | 确认可交给 OpenSpec |
| `bmad-generate-project-context` | `project-context.md` | 供 OpenSpec apply 时保持一致性 |

### 4.7 BMAD 禁止使用的 Skills

以下属于 BMAD **Phase 4 Implementation**，在本项目中 **禁止使用**：

| 禁用项 | 原因 |
|--------|------|
| `bmad-sprint-planning` / `sprint-status.yaml` | 冲刺与任务状态由 OpenSpec change 管理 |
| `bmad-create-story` / Story 卡片中的 Tasks 列表 | 与 OpenSpec `tasks.md` 冲突 |
| `bmad-dev-story` | 代码实现由 `/opsx:apply` 驱动 |
| `bmad-code-review`（作为实施闭环） | 不替代 OpenSpec tasks |

> 若 AI 试图生成「开发任务清单」「按 Story 的 TODO」，应立即中止并提示：
> **「请只输出 OpenSpec 格式的 proposal 草稿，tasks 由 OpenSpec 生成。」**

---

## 5. 用户衔接操作

### 5.1 衔接概述

BMAD 规划完成后，**用户需要手工将**每个 BMAD slice 对应的 `proposal.md` 和 `design.md` 导入到 MaterialMonospec 主仓库的 OpenSpec change 中。

### 5.2 衔接步骤

对每个 `_bmad-output/planning-artifacts/<epic>/slices/<name>/`：

#### 步骤 1：确认目标仓库

确定该 slice 主要影响哪个子仓库（MaterialClient / UrbanManagement / 跨仓库）。

#### 步骤 2：创建 OpenSpec change

在 MaterialMonospec 主仓库根目录：

```bash
# 创建新变更
openspec create <change-name>
```

变更命名规范：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `add-*` | 新功能 | `add-batch-weighing` |
| `update-*` | 更新功能 | `update-weighing-flow` |
| `remove-*` | 移除功能 | `remove-legacy-report` |
| `refactor-*` | 重构 | `refactor-data-access` |
| `fix-*` | 修复 | `fix-weight-calculation` |

#### 步骤 3：导入 proposal

任选其一：

**方式 A**：通过 Cursor 对话导入

```
/opsx:propose <change-id>
```

将 BMAD 的 `proposal.md` 内容作为对话上下文粘贴。

**方式 B**：手动创建目录并写入文件

手动创建 `openspec/changes/<change-id>/` 目录，将 BMAD 产出的 `proposal.md` 内容写入。

#### 步骤 4：导入 design（可选）

将 BMAD 的 `design.md` 放在 change 目录或对话中声明为 apply 参考。

> **不要**用 BMAD 文件覆盖 OpenSpec 自动生成的 `tasks.md`。

#### 步骤 5：引用 project-context（可选）

若存在 `project-context.md`，在 `openspec/config.yaml` 或 apply 提示中引用。

### 5.3 衔接检查清单

在衔接完成后，逐项确认：

- [ ] 一个 BMAD slice 对应一个 OpenSpec change（避免一个 change 吞整个 epic）
- [ ] change 命名与 slice 一致（kebab-case）
- [ ] 未从 BMAD 拷贝任何任务列表到仓库
- [ ] 跨仓库 slice 已在主仓库中创建对应的 change（注意：所有 OpenSpec 工件都在主仓库）
- [ ] proposal 中的「影响的子仓库」已正确标注
- [ ] BMAD design 作为参考已附上（不覆盖 OpenSpec 生成内容）

---

## 6. OpenSpec 执行阶段操作

### 6.1 执行流程

```
propose → specs → design → tasks → apply → archive
```

### 6.2 propose：创建提案

```
/opsx:propose <change-id>
```

OpenSpec 基于 BMAD 草稿扩写正式的 `proposal.md`。

### 6.3 specs：编写规范

在 `openspec/changes/<change-id>/specs/` 目录中创建 delta spec：

- **ADDED**：新增能力的完整 spec
- **MODIFIED**：修改能力的变更描述
- **REMOVED**：移除能力的说明

### 6.4 design：细化设计

```
/opsx:apply
```

OpenSpec 可吸收 BMAD 概要 design，扩展为完整的 change 内 design。

> 参见 `PROPOSAL_DESIGN_GUIDELINES.md` 获取设计可视化标准（ASCII 图、Mermaid 图等）。

### 6.5 tasks：生成任务清单

**`tasks.md` 仅由 OpenSpec 生成和维护**。

```bash
# 验证变更完整性
openspec validate <change-name> --strict
```

### 6.6 apply：实现代码

在 `tasks.md` 指引下实现代码：

- **MaterialClient 相关变更**：在 `repos/MaterialClient/` 中实现
- **UrbanManagement 相关变更**：在 `repos/UrbanManagement/` 中实现

每完成一个任务，在 `tasks.md` 中标记：

```markdown
- [x] 已完成的任务
- [ ] 待完成的任务
```

### 6.7 archive：归档变更

```bash
# 归档完成的变更
openspec archive <change-name>
```

归档行为：
- 变更目录从 `changes/<name>/` 移动到 `changes/archive/<name>/`
- 如果 `commit_when_archive: true`（已在 `monospecs.yaml` 中配置），specs 变更会自动提交到主仓库 Git
- **子仓库的代码变更不会自动提交**，需手动在各子仓库中提交和推送

### 6.8 制品负责方

| 制品 | 负责方 |
|------|--------|
| `proposal.md` | OpenSpec（可基于 BMAD 草稿扩写） |
| `specs/**/*.md` | OpenSpec |
| `design.md` | OpenSpec（可吸收 BMAD 概要 design） |
| **`tasks.md`** | **仅 OpenSpec** |
| 实现与勾选任务 | `/opsx:apply` |

---

## 7. 完整端到端流程示例

### 7.1 场景：MaterialClient 新增批量称重功能

#### 阶段 A：BMAD 规划

**A1. 进入 Cursor，加载 BMAD**

```
使用 bmad-help，我要为 MaterialClient 新增批量称重功能。
```

**A2. 创建 PRD**

```
加载 bmad-create-prd skill，创建批量称重功能的 PRD：
- 支持多人排队称重
- 自动分配称重点位
- 实时显示排队状态
- 称重完成后自动打印小票
```

**A3. 架构设计**

```
加载 bmad-create-architecture skill，基于当前 PRD 设计架构。
需要考虑 MaterialClient 的 Avalonia + ReactiveUI + ABP 技术栈。
```

**A4. 拆分为多个 proposal 切片**

```
bmad-help，把这个 Epic 拆成可独立交付的 OpenSpec change。
每个 slice 只输出 proposal.md 和概要 design.md，不要生成 tasks。
```

预期产出（在 `_bmad-output/planning-artifacts/` 中）：

```
slices/
├── 01-batch-queue-management/
│   ├── proposal.md
│   └── design.md
├── 02-batch-weighing-api/
│   ├── proposal.md
│   └── design.md
└── 03-batch-report-ui/
    ├── proposal.md
    └── design.md
```

**A5. 就绪检查**

```
加载 bmad-check-implementation-readiness skill，检查规划是否就绪。
```

#### 阶段 B：用户衔接

**B1. 对第一个 slice 创建 change**

```bash
openspec create add-batch-queue-management
```

**B2. 导入 proposal**

将 `_bmad-output/planning-artifacts/.../slices/01-batch-queue-management/proposal.md` 的内容导入：

```
/opsx:propose add-batch-queue-management
（粘贴 BMAD proposal 内容）
```

**B3. 附上 design 参考**

将 BMAD 的 `design.md` 作为 apply 参考传入。

**B4. 重复 B1-B3 对其余 slice 操作**

```bash
openspec create add-batch-weighing-api
openspec create add-batch-report-ui
```

#### 阶段 C：OpenSpec 执行

**C1. 执行第一个 change**

```
/opsx:apply add-batch-queue-management
```

在 `repos/MaterialClient/` 中实现代码变更。

**C2. 完成后归档**

```bash
openspec archive add-batch-queue-management
```

**C3. 按顺序继续后续 change**

```
/opsx:apply add-batch-weighing-api
# ... 实现代码 ...
openspec archive add-batch-weighing-api

/opsx:apply add-batch-report-ui
# ... 实现代码 ...
openspec archive add-batch-report-ui
```

**C4. 提交子仓库代码**

```bash
# 在 MaterialClient 子仓库中提交代码
cd repos/MaterialClient
git add .
git commit -m "feat: add batch weighing functionality"
git push
```

---

## 8. 跨仓库变更操作

当变更涉及 MaterialClient 和 UrbanManagement 两个子仓库时：

### 8.1 BMAD 规划阶段

在架构设计中明确标注各 slice 影响的子仓库：

```
加载 bmad-create-architecture skill，需要考虑跨仓库边界：
- MaterialClient（桌面端）：UI 交互、本地数据管理
- UrbanManagement（服务端）：API 接口、数据持久化、业务逻辑
```

### 8.2 衔接与执行

- 在 proposal 中明确标注「影响的子仓库」
- `tasks.md` 中分列每个子仓库的实施任务
- 代码实现**分别**在各自子仓库中完成
- 所有 OpenSpec 工件**统一**在主仓库管理

### 8.3 示例：数据同步功能

| BMAD Slice | 影响子仓库 | OpenSpec Change |
|------------|-----------|-----------------|
| 同步 API | UrbanManagement | `add-sync-api` |
| 同步 UI | MaterialClient | `add-sync-ui` |
| 冲突处理 | 两者 | `add-conflict-resolution` |

---

## 9. 制品格式规范

### 9.1 BMAD 侧 proposal.md（草稿）

与 OpenSpec propose 对齐，便于粘贴：

```markdown
## Why
（为什么需要这个变更）

## What Changes
（变更内容列表）

## Capabilities
### New Capabilities
（新增能力）
### Modified Capabilities
（修改能力）

## Impact
（影响分析）
```

### 9.2 BMAD 侧 design.md（概要）

```markdown
## Context
（上下文）

## Goals / Non-Goals
（目标 / 非目标）

## Decisions
（关键决策）

## Risks / Trade-offs
（风险和权衡）
```

> **不写**：实现步骤、文件级修改列表、checkbox 任务（这些属于 OpenSpec `tasks.md`）。

### 9.3 OpenSpec change（正式）

遵循 OpenSpec 标准目录结构：

```
openspec/changes/<change-id>/
├── proposal.md
├── design.md
├── specs/
│   └── <capability>.md
└── tasks.md
```

`tasks.md` 只在 OpenSpec 生成后出现。

---

## 10. 故障排查

### 10.1 BMAD 相关

| 现象 | 处理 |
|------|------|
| Cursor 找不到 BMAD skill | 确认 `--tools cursor` 安装；检查 `.agents/skills/` 下是否存在 `SKILL.md` |
| Skill 与 OpenSpec 命令混淆 | 规划阶段只提 `bmad-*`；执行阶段只提 `/opsx:*` |
| 仍生成 Story/tasks | 在规则中重申「任务清单仅 OpenSpec」；限定输出格式 |
| BMAD 试图直接写代码 | 中止并提示「规划结束后使用 /opsx:propose」 |

### 10.2 OpenSpec 相关

| 现象 | 处理 |
|------|------|
| `openspec` 命令未找到 | 运行 `npm install -g @fission-ai/openspec@latest` |
| change 创建失败 | 确认在 MaterialMonospec 主仓库根目录操作 |
| specs 未更新 | 检查 `openspec/specs/` 目录权限和内容 |
| 归档失败 | 确认所有 tasks 已完成（`- [x]`），运行 `openspec validate --strict` |

### 10.3 子仓库相关

| 现象 | 处理 |
|------|------|
| 子仓库目录为空 | 运行 `git submodule update --init --recursive` |
| 代码变更无法提交 | 子仓库需单独 `git add` / `git commit` / `git push` |
| 子仓库有遗留 openspec 目录 | 忽略，所有新变更在主仓库 `openspec/` 中操作 |

---

## 11. 反模式警告

> **以下操作均属于反模式，必须避免。**

| 反模式 | 正确做法 |
|--------|----------|
| BMAD `bmad-dev-story` 与 `/opsx:apply` 同时跑 | 只用 OpenSpec apply |
| 把 Story 卡片 Tasks 复制进 `tasks.md` | 删除；让 OpenSpec 重新生成 tasks |
| 一个 OpenSpec change 包含整个 epic | 按 BMAD slice 拆多个 change |
| 期望 BMAD 自动 `openspec init` | 用户在主仓库手工 init + propose |
| 在子仓库中创建或修改 openspec 工件 | 只在主仓库 `openspec/` 中操作 |
| 在 BMAD 中生成 `tasks.md` | tasks 仅由 OpenSpec 生成 |
| 跳过 BMAD 规划直接创建 change | 对于非平凡变更，应先通过 BMAD 完成 Epic 级规划 |
| 概要 design 过薄导致 apply 信息不足 | design 至少包含 Decisions；细节由 OpenSpec 展开 |

---

## 12. 快速参考卡

### 常用命令速查

```bash
# === BMAD ===
npx bmad-method install --modules bmm --tools cursor   # 安装 BMAD

# === OpenSpec ===
openspec init                                          # 初始化
openspec create <change-name>                          # 创建变更
openspec list                                          # 查看活动变更
openspec list --specs                                  # 查看 specs
openspec validate <change-name> --strict               # 验证变更
openspec archive <change-name>                         # 归档变更
openspec status --change <change-name> --json          # 查看变更状态

# === 验证脚本 ===
powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1
powershell -ExecutionPolicy Bypass -File scripts/validate-migration.ps1
```

### Cursor 阶段切换口令

| 阶段 | 口令示例 |
|------|----------|
| **规划启动** | `使用 bmad-help，我要规划 [Epic 描述]` |
| **创建 PRD** | `加载 bmad-create-prd skill，基于 [需求描述]` |
| **架构设计** | `加载 bmad-create-architecture skill，基于当前 PRD` |
| **拆分切片** | `bmad-help，把这个 Epic 拆成 N 个 OpenSpec change，每个只要 proposal 和概要 design` |
| **就绪检查** | `加载 bmad-check-implementation-readiness skill` |
| **衔接** | 用户手工操作：复制 BMAD 产出到 OpenSpec change |
| **执行提案** | `/opsx:propose <change-id>` |
| **执行实现** | `/opsx:apply` |
| **归档** | `openspec archive <change-name>` |

### 关键约束速记

```
BMAD = 想（规划）
用户 = 桥（衔接）
OpenSpec = 做（执行）
tasks.md = 仅 OpenSpec
所有 OpenSpec 工件 = 仅主仓库
```

---

*本操作手册基于 `skill-vault/docs/2026-05-18-plan-methodology-research/` 调研成果，结合 MaterialMonospec 项目实际情况编写。方法论源文件参考：`repos/bmad-method`、`repos/openspec`。*
