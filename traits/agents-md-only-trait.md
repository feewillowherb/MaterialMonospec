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

## 强制规则

1. **新目录说明**：需要给人 / Agent 看的约定、目录索引、如何运行 → 写 **`AGENTS.md`**，文件名固定，不用其它别名。
2. **禁止新建 README**：脚手架、Graph、`pipelines/`、`traits/`、`openspec/`、`docs/` 专题目录等 **MUST NOT** 落盘 `README.md`。
3. **禁止在文档中推荐 README**：链接、表格、「见 xxx/README」**MUST** 改为 `AGENTS.md`。
4. **触达即迁移**：改到仍含 `README.md` 的目录说明时，**MUST** 将内容迁入同级 `AGENTS.md` 并删除（或不再引用）该 `README.md`；不要双轨并存。
5. **根约定**：本仓根入口保持 **`AGENTS.md`**；`CLAUDE.md` 仅允许指向 `AGENTS.md`，**MUST NOT** 再引入根 `README.md`。

## 允许的例外（窄）

仅下列情况可不建 / 可不迁 `README.md`，且 **MUST** 在变更说明中写明例外原因：

| 例外 | 说明 |
|------|------|
| 第三方 / 生成物 | `node_modules/`、工具生成且不可控的上游模板 |
| 子仓远端既有文件 | `repos/<Name>/` 内尚未授权修改的上游 `README.md`（只读探索可以；**本仓新增内容仍写 AGENTS.md**） |
| 包发布强制字段 | 某注册表硬性要求 `readme` 字段时，在 OpenSpec change / proposal 中声明；正文仍以 `AGENTS.md` 为权威，README 仅作发布镜像且注明「勿手改，以 AGENTS.md 为准」 |

除此以外，**无「给人看比较习惯」类例外**。

## 命名与内容

- 文件名：**`AGENTS.md`**（全大写 `AGENTS`）。
- 语言：与根 `AGENTS.md` 一致——说明性中文；路径、命令、标识符保持原文。
- 内容：约定、目录、MUST/MUST NOT、如何运行、非目标；**不要**写成营销式项目首页。

## Agent 检查清单

- [ ] 本次是否新建了任何 `README.md`？有 → **拒绝 / 改写为 AGENTS.md**
- [ ] 文档链接是否仍指向 `README.md`？有 → **改为 AGENTS.md**
- [ ] `traits/` 索引是否为 `traits/AGENTS.md`（而非 `traits/README.md`）？
- [ ] 新 pipeline / graph / docs 目录是否用 `AGENTS.md` 或既有 `pipeline.md` 等专题文件，而非 README？

## 与其它文档的关系

| 类型 | 是否替代 AGENTS.md |
|------|-------------------|
| `pipeline.md` / `acceptance.md` / OpenSpec `proposal.md` | 否——专题产物，保留；**目录入口**仍用 AGENTS.md（若需要索引） |
| `traits/*.md` | 否——单条契约；**traits 目录索引**用 `traits/AGENTS.md` |
| 根 `CLAUDE.md` | 否——仅指针到 `AGENTS.md` |

## 反模式

| 反模式 | 正确做法 |
|--------|----------|
| `pipelines/README.md` | `pipelines/AGENTS.md` |
| `traits/README.md` | `traits/AGENTS.md` |
| 在回复里写「见 README」 | 写「见 AGENTS.md」 |
| 同时保留 README + AGENTS「过渡」 | 迁完即删 README，避免双入口 |
