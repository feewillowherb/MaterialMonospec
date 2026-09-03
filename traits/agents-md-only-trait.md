# agents-md-only

Trait: 仅 **AGENTS.md**（禁止 **README.md**）作为目录说明、模块约定、索引与操作指引入口。

适用范围：MaterialMonospec 工作区内**人工 / Agent 编写**的目录说明、模块约定、索引与操作指引。  
加载时机：新建或改写目录文档、脚手架、pipeline / openspec / traits / docs 索引之前 **MUST** 加载本 trait。  
本 trait **仅**留在 monospec 本仓 `traits/`（与 `openspec-git-workflow` 同类）；**不要**当作 C# 编码 trait 同步到 MaterialClient / UrbanManagement / FdSoft.BasePlatform 的 `traits/` 副本。

## 原则

| 角色 | 唯一入口 |
|------|----------|
| 人（协作者） | 目录下的 **`AGENTS.md`** |
| Agent | 同路径 **`AGENTS.md`**（及根 `AGENTS.md` / `CLAUDE.md` 指针） |

**MUST NOT** 使用、新建、更新或引导阅读 **`README.md` / `readme.md` / `ReadMe.md`**（任意大小写变体）作为项目说明或约定入口。

## 只有 README 时的致命缺陷（The Fatal Flaw）

即便 Agent 能认出「这是专业目录」，若缺少**专为机器设计的契约**（如 `AGENTS.md`），行为仍会系统性失真。`README.md` 给人读可以；**单独**当作目录入口对 Agent **不够**。

| 缺陷 | 表现 |
|------|------|
| **缺乏执行边界**（Lack of Execution Boundaries） | README 多为**描述性**（Descriptive），如「本项目旨在提升效率」；Agent 需要的是**指令性**（Directive）硬约束，如「严禁在本目录修改路由配置」。无强约束时易越界改不该动的文件。 |
| **退化为通用模式**（Fallback to Generic Patterns） | 无该目录的 SOP（Standard Operating Procedure）时，Agent 会回退到训练里的「最大公约数」经验，用通用但不符合本仓规范的风格 / 架构生成内容。 |
| **忽略隐性规则**（Ignoring Implicit Rules） | 人类能从 README 字里行间猜出未写明的规矩；Agent **没有**这种直觉。诸如「新文件必须以特定前缀命名」若不写成机器可读的硬性指令，就会被直接忽略。 |

因此本 trait 要求入口是 **`AGENTS.md`**：以 MUST / MUST NOT、边界、SOP 为主，而不是营销式或仅描述意图的 README。

## 专业目录 MUST 有 AGENTS.md

**专业目录**：编排仓内承担**独立职责**、可被单独寻址的约定根 / 领域根（不是任意叶子文件夹）。

### 词表（MUST 落盘 `AGENTS.md`）

| 层级 | 路径示例 | 要求 |
|------|----------|------|
| 仓根 | `/`（仓库根） | 已有根 `AGENTS.md` |
| 顶层专业根 | `pipelines/`、`traits/`、`docs/`、`openspec/`、`scripts/` | **MUST** 有同级 `AGENTS.md` |
| 新建顶层专业根 | 未来新增的同类顶层目录（如新工具域） | 建目录时 **MUST 同时**生成 `AGENTS.md` |
| 领域一层 | `pipelines/graphs/<domain>/`（如 `govsync/`、`materialclient/`） | **MUST** 有该 domain 的 `AGENTS.md`（索引本域 Graph / 选型补充） |
| 子仓根 | `repos/<Name>/` | 以各子仓既有 `AGENTS.md` 为准（本 trait 不替代子仓约定） |

### 新建时（NON-NEGOTIABLE）

1. **新建专业目录**（上表任一层级）时，**MUST** 在该目录下**同时**生成 **`AGENTS.md`**，不得「先空目录、后补文档」。
2. `AGENTS.md` 至少包含：本目录职责、MUST / MUST NOT、与父级 `AGENTS.md` 的边界、如何运行或索引子项。
3. 触达尚无 `AGENTS.md` 的既有专业目录时：**MUST** 补建（可先写最小索引 + 指针到父级），再改其内容。

### 不必强制 AGENTS.md 的叶子（避免爆炸）

下列**不是**「专业目录」强制点；保留专题文件即可，**MUST NOT** 为每个叶子强行复制一份空 AGENTS：

| 叶子 | 权威文件 |
|------|----------|
| 单条 Graph `pipelines/graphs/<domain>/<slug>/` | `pipeline.md`（+ `config.yaml` 等） |
| 单条 OpenSpec change `openspec/changes/<name>/` | `proposal.md` / `tasks.md` 等 |
| 单条 trait 文件 `traits/*-trait.md` | 该 trait 正文；**目录索引**仍是 `traits/AGENTS.md` |
| `runs/`、`fixtures/`、纯产物 / 证据目录 | 无约定入口要求 |

若叶子目录需要给人 / Agent 的**额外边界**（超出 `pipeline.md`），仍写同级 `AGENTS.md`，且 **MUST NOT** 用 README。

## 强制规则

1. **新目录说明**：需要给人 / Agent 看的约定、目录索引、如何运行 → 写 **`AGENTS.md`**，文件名固定，不用其它别名。
2. **专业目录必有入口**：见上节；缺则补建，新建则同批生成。
3. **禁止新建 README**：脚手架、Graph、`pipelines/`、`traits/`、`openspec/`、`docs/` 专题目录等 **MUST NOT** 落盘 `README.md`。
4. **禁止在文档中推荐 README**：链接、表格、「见 xxx/README」**MUST** 改为 `AGENTS.md`。
5. **触达即迁移**：改到仍含 `README.md` 的目录说明时，**MUST** 将内容迁入同级 `AGENTS.md` 并删除（或不再引用）该 `README.md`；不要双轨并存。
6. **根约定**：本仓根入口保持 **`AGENTS.md`**；`CLAUDE.md` 仅允许指向 `AGENTS.md`，**MUST NOT** 再引入根 `README.md`。

## 允许的例外（窄）

仅下列情况可不建 / 可不迁 `README.md`，且 **MUST** 在变更说明中写明例外原因：

| 例外 | 说明 |
|------|------|
| 第三方 / 生成物 | `node_modules/`、工具生成且不可控的上游模板 |
| 子仓远端既有文件 | `repos/<Name>/` 内尚未授权修改的上游 `README.md`（只读探索可以；**本仓新增内容仍写 AGENTS.md**） |
| 包发布强制字段 | 某注册表硬性要求 `readme` 字段时，在 OpenSpec change / proposal 中声明；正文仍以 `AGENTS.md` 为权威，README 仅作发布镜像且注明「勿手改，以 AGENTS.md 为准」 |

除此以外，**无「给人看比较习惯」类例外**。  
**注意**：上表**不豁免**「专业目录缺少 AGENTS.md」——专业目录仍 **MUST** 有 `AGENTS.md`。

## 命名与内容

- 文件名：**`AGENTS.md`**（全大写 `AGENTS`）。
- 语言：与根 `AGENTS.md` 一致——说明性中文；路径、命令、标识符保持原文。
- 内容：约定、目录、MUST/MUST NOT、如何运行、非目标；**不要**写成营销式项目首页。

## Agent 检查清单

- [ ] 本次是否新建了任何 `README.md`？有 → **拒绝 / 改写为 AGENTS.md**
- [ ] 本次是否新建 / 触达专业目录却无同级 `AGENTS.md`？有 → **同批生成或补建**
- [ ] 文档链接是否仍指向 `README.md`？有 → **改为 AGENTS.md**
- [ ] `traits/` 索引是否为 `traits/AGENTS.md`（而非 `traits/README.md`）？
- [ ] 新 pipeline **domain** / docs / openspec / scripts 根是否已有 `AGENTS.md`？Graph **slug** 是否用 `pipeline.md` 而非 README？

## 与其它文档的关系

| 类型 | 是否替代 AGENTS.md |
|------|-------------------|
| `pipeline.md` / `acceptance.md` / OpenSpec `proposal.md` | 否——专题产物，保留；**专业目录 / domain 入口**仍用 AGENTS.md |
| `traits/*.md` | 否——单条契约；**traits 目录索引**用 `traits/AGENTS.md` |
| 根 `CLAUDE.md` | 否——仅指针到 `AGENTS.md` |

## 反模式

| 反模式 | 正确做法 |
|--------|----------|
| `pipelines/README.md` | `pipelines/AGENTS.md` |
| `traits/README.md` | `traits/AGENTS.md` |
| 新建 `pipelines/graphs/foo/` domain 无 AGENTS.md | 同批写 `pipelines/graphs/foo/AGENTS.md` |
| 每个 Graph slug 都空拷一份 AGENTS.md | slug 用 `pipeline.md`；domain / 顶层才强制 AGENTS |
| 在回复里写「见 README」 | 写「见 AGENTS.md」 |
| 同时保留 README + AGENTS「过渡」 | 迁完即删 README，避免双入口 |
