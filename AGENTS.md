# MaterialMonospec - Agent 行为准则

## 项目概述

MaterialMonospec 是一个 Monospec 主仓库，统一管理 MaterialClient（工业材料称重桌面应用）、UrbanManagement（城市管理 Web 应用）和 FdSoft.BasePlatform（企业级基础平台 Web 应用）等子仓库的 OpenSpec 文档。所有变更的 proposal、design、specs、tasks 在主仓库中创建和管理，代码实现仍在各自的子仓库中进行。

## 子仓库 AGENTS

在 `repos/` 下编写或修改代码前，须读取对应子仓库的 `AGENTS.md`：

- `repos/MaterialClient/AGENTS.md`
- `repos/UrbanManagement/AGENTS.md`
- `repos/FdSoft.BasePlatform/AGENTS.md`

跨子仓库 C# 约定（含 Record 替代 Tuple）见下文「跨子仓库 C# 编码约定」；实现前仍须阅读对应子仓库 `AGENTS.md`，冲突时以**更严格**者为准。

ViewModel / 界面层 **不得**直接使用 Repository：规则在 `traits/viewmodel-no-repository-trait.md`，**不要**写入各子仓库 `AGENTS.md`。

## 目录结构

```
MaterialMonospec/
├── openspec/
│   ├── changes/                          # 活动变更
│   │   └── <change-name>/               # 变更目录
│   │       ├── proposal.md
│   │       ├── design.md
│   │       ├── specs/
│   │       └── tasks.md
│   ├── changes/archive/                  # 归档变更（历史记录）
│   └── specs/                            # 规范定义（51个）
├── repos/                                # 子仓库（目录联接）
│   ├── MaterialClient/                   # Avalonia 桌面应用
│   ├── UrbanManagement/                  # ABP Web 应用
│   └── FdSoft.BasePlatform/              # ASP.NET Core MVC 基础平台
├── docs/                                 # 文档（产出约定见 docs/AGENTS.md）
│   ├── AGENTS.md                         # 仅约束 docs/ 的调研产出格式
│   ├── monospecs-yaml-template.md        # 配置模板
│   ├── add-repo-guide.md                 # 添加子仓库指南
│   ├── migration-guide.md                # 迁移指南
│   └── troubleshooting.md               # 故障排除
├── scripts/                              # 工具脚本
│   ├── validate-config.ps1               # 配置验证
│   └── validate-migration.ps1            # 迁移验证
├── .hagicode/                            # HagiCode 配置
│   ├── monospecs.yaml                    # 子仓库映射（目录联接）
│   └── standard_words.yaml               # 标准用语
├── PROPOSAL_DESIGN_GUIDELINES.md         # 提案设计指南
├── traits/                               # Agent 行为 traits（可被本文件 require）
├── pipelines/                            # 可 cook 验收 Graph（框架 + graphs/）；约定见 pipelines/AGENTS.md
├── _bmad/                                # BMAD 配置与工作流（仅主仓库，子仓库不安装）
├── _bmad-output/                         # BMAD 规划/实现产出
├── .agents/skills/                       # Cursor BMAD skills
├── AGENTS.md                             # 本文件
└── .gitignore                            # 排除 repos/、BMAD 个人配置
```

## Monospec 工作流程

### 完整工作流概览

```
创建变更 → 编写提案 → 审查设计 → 实现代码 → 归档变更
   |           |           |           |           |
   v           v           v           v           v
 主仓库      主仓库      主仓库     子仓库      主仓库
 openspec/   proposal   design    repos/XX/   archive +
             specs      tasks     代码实现     自动提交
```

### 1. 变更创建

所有变更在主仓库中创建：

```bash
# 创建新变更
openspec create <change-name>

# 查看活动变更
openspec list

# 查看变更状态
openspec status --change <change-name> --json
```

变更命名规范：
- `add-*`：新功能
- `update-*`：更新功能
- `remove-*`：移除功能
- `refactor-*`：重构
- `fix-*`：修复

### 2. 编写提案和设计

在变更目录中编写工件：

1. **proposal.md**：说明 Why（为什么）、What Changes（变更内容）、Capabilities（能力）、Impact（影响）
2. **design.md**：技术决策、组件架构、数据流、风险和权衡
3. **specs/**：每个受影响能力的 delta spec（ADDED/MODIFIED/REMOVED）
4. **tasks.md**：实施任务清单

### 3. 规范管理

所有 specs 存储在 `openspec/specs/` 目录中：

```bash
openspec list --specs    # 查看所有 specs
```

每个 spec 目录包含 `spec.md`，定义该能力的需求（Requirements）和场景（Scenarios）。

## 子仓库代码实现流程

### 涉及 MaterialClient 的变更

1. 在主仓库创建变更提案
2. 在 `repos/MaterialClient/` 中实现代码变更
3. MaterialClient 技术栈：
   - C# 13 / .NET 10.0 / Avalonia UI 11.3.9 / ReactiveUI
   - ABP Framework / SQLite (Entity Framework Core)
   - MVVM 模式，View-ViewModel 分离
4. 代码提交和推送需在 MaterialClient 仓库中单独操作

### 涉及 UrbanManagement 的变更

1. 在主仓库创建变更提案
2. 在 `repos/UrbanManagement/` 中实现代码变更
3. UrbanManagement 技术栈：
   - ABP Framework / .NET
   - Web 应用
4. 代码提交和推送需在 UrbanManagement 仓库中单独操作

### 涉及 FdSoft.BasePlatform 的变更

1. 在主仓库创建变更提案
2. 在 `repos/FdSoft.BasePlatform/` 中实现代码变更
3. FdSoft.BasePlatform 技术栈：
   - C# 10 / .NET 6.0 / ASP.NET Core MVC
   - SqlSugar / SQL Server
   - 分层架构：Controller → Service → Repository
4. 代码提交和推送需在 FdSoft.BasePlatform 仓库中单独操作

### 跨仓库变更

如果变更涉及多个子仓库：
- 在提案中明确说明每个子仓库的影响范围
- tasks.md 中分列每个子仓库的实施任务
- 代码实现分别在各自的子仓库中完成

## 变更创建和归档流程

### 创建变更

```bash
# 步骤 1：创建变更
openspec create <change-name>

# 步骤 2：编写 proposal.md
# 步骤 3：编写 design.md（如需要）
# 步骤 4：创建 specs/ 下的 delta spec
# 步骤 5：编写 tasks.md

# 步骤 6：验证变更
openspec validate <change-name> --strict
```

### 实现变更

```bash
# 在 tasks.md 指引下实现代码
# 每完成一个任务，在 tasks.md 中标记：- [ ] -> - [x]
```

### 归档变更

```bash
# 归档完成的变更
openspec archive <change-name>
```

归档行为：
- 变更目录从 `changes/<name>/` 移动到 `changes/archive/<name>/`
- 如果 `commit_when_archive: true`，specs 变更会自动提交到主仓库 Git
- **子仓库的代码变更不会自动提交**，需手动在各子仓库中提交和推送

## 配置说明

主仓库使用 `.hagicode/monospecs.yaml` 配置子仓库信息（HagiCode 读取此文件）：

```yaml
version: "1.0"              # 配置版本（字符串）
repo_dir: repos              # 子仓库目录
commit_when_archive: true    # 归档时自动提交 specs
repositories:                # 子仓库列表
  - path: repos/MaterialClient
    url: https://github.com/feewillowherb/MaterialClient.git
    displayName: MaterialClient
    type: Desktop
    optional: false
    tags: [avalonia, industrial]
```

详细配置说明见 `docs/monospecs-yaml-template.md`。

## 子仓库项目信息

### MaterialClient

- **类型**：Windows 桌面应用（Avalonia UI）
- **技术栈**：C# 13 / .NET 10.0 / Avalonia UI 11.3.9 / ReactiveUI / ABP Framework / SQLite
- **用途**：工业环境材料称重管理，支持有人/无人值守称重
- **架构**：MVVM + DDD + 分层架构
- **详情**：参见 `PROPOSAL_DESIGN_GUIDELINES.md`

### UrbanManagement

- **类型**：Web 应用（ABP Framework）
- **技术栈**：ABP Framework / .NET
- **用途**：城市管理 Web 应用

### FdSoft.BasePlatform

- **类型**：Web 应用（ASP.NET Core MVC）
- **技术栈**：C# 10 / .NET 6.0 / SqlSugar / SQL Server
- **用途**：建筑行业劳务实名制、项目管理、设备监控、考勤等企业级基础平台
- **架构**：Controller → Service → Repository 分层
- **详情**：参见 `repos/FdSoft.BasePlatform/AGENTS.md`

## 跨子仓库 C# 编码约定

以下约定适用于 `repos/MaterialClient` 与 `repos/UrbanManagement` 中的 C# 代码。各子仓库 `AGENTS.md` 中有更细的本地约定。

### Record 替代 Tuple（NON-NEGOTIABLE）

- 禁止使用 C# tuple（如 `(string, int)`、`(string? a, int b)`）及 `ValueTuple` / `System.Tuple<...>` 作为**方法返回值、方法参数、局部变量类型、字段类型**。
- 多值组合应使用**命名 `record`**，例如 `record SyncResult(bool Success, string? Message)`。
- OpenSpec 的 `design.md`、API 草图及 `tasks.md` 中的方法签名不得使用 tuple；实现与文档一致使用 `record`。
- **边界**：第三方/BCL API 若返回 tuple，仅在适配层解构并立即映射为项目内 `record`，不得将 tuple 类型向上层或跨模块传播。
- 架构图或设计叙述中的 “tuple” 仅表示概念上的多值组合，实现仍须使用命名 `record`。

### 代码审查检查项

- [ ] 未使用 tuple 作为返回值、参数、局部变量或字段类型
- [ ] 多值类型为命名 `record`（DTO、值对象、查询结果等）
- [ ] OpenSpec 设计文档中的 API 签名未使用 tuple

## 工具和验证

```bash
# 验证配置文件
powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1

# 验证迁移完整性
powershell -ExecutionPolicy Bypass -File scripts/validate-migration.ps1

# 验证 OpenSpec 实现是否符合 AGENTS.md（归档前建议执行）
# Cursor: /opsx-verify-agents <change-name>
powershell -ExecutionPolicy Bypass -File scripts/validate-agents-implementation.ps1 `
  -ChangeName "<change-name>" `
  -FileListPath ".cursor/.opsx-verify-<change-name>-files.txt" `
  -Repos "MaterialClient,UrbanManagement"
```

## OpenSpec 生成位置约束

> **关键规则：所有 OpenSpec 工件必须且只能在 MaterialMonospec 主仓库中生成和管理。**

### 约束说明

- **唯一的 OpenSpec 根目录**：`MaterialMonospec/openspec/` 是本项目唯一的 OpenSpec 工作目录
- **禁止在子仓库中生成 OpenSpec**：不得在 `repos/` 下的任何子项目（如 `repos/MaterialClient/`、`repos/UrbanManagement/`）中创建或修改 openspec 工件（proposal、design、specs、tasks 等）
- **子仓库中已有的 openspec 目录**：`repos/` 下子仓库中可能存在历史遗留的 openspec 目录，这些不应再被使用。所有新的变更提案、设计、规范和任务都必须在主仓库的 `openspec/` 目录中创建
- **变更范围覆盖所有子仓库**：无论变更涉及 MaterialClient、UrbanManagement 还是两者，对应的 OpenSpec 工件都统一在主仓库中管理

### 正确与错误示例

| 场景 | ✅ 正确位置 | ❌ 错误位置 |
|------|-----------|-----------|
| 创建变更提案 | `MaterialMonospec/openspec/changes/add-xxx/proposal.md` | `repos/MaterialClient/openspec/changes/add-xxx/proposal.md` |
| 编写设计文档 | `MaterialMonospec/openspec/changes/add-xxx/design.md` | `repos/UrbanManagement/openspec/changes/add-xxx/design.md` |
| 管理规范定义 | `MaterialMonospec/openspec/specs/` | `repos/*/openspec/specs/` |
| 编写实施任务 | `MaterialMonospec/openspec/changes/add-xxx/tasks.md` | `repos/*/openspec/changes/add-xxx/tasks.md` |

## AI Pipeline（生成 / 执行）

与 OpenSpec 同构、**不是** OpenSpec：`/gen-pipeline` 对 propose，`/run-pipeline` 对 apply。

- **约定入口**：`pipelines/AGENTS.md`（分层 `graphs/<domain>/<slug>/`、选型、新建/退役）
- 哲学深潜：`docs/2026-08-13-ai-pipeline-design-philosophy/`（cook 协议以 Graph + AGENTS.md 为准）
- 现行 Graph：`pipelines/graphs/<domain>/<slug>/`（模板 `pipelines/_template/`）
- 命令：`.cursor/commands/gen-pipeline.md`、`run-pipeline.md`，以及 `/gen-<family>-pipeline`、`/run-<family>-pipeline`
- Family：`observe` | `ingest` | `probe` | `reconcile` | `transform`
- **禁止**：修产品行为走 OpenSpec，不塞进 runner；密钥进 `secrets.local.yaml`；覆盖旧 `runs/`；Agent 宣布 L3 通过

生成默认只写工件。用户确认后才执行。Agent 不得宣布 L3 验收通过。

## Required traits

以下 trait **默认生效**。涉及对应场景时，Agent **必须先阅读**该文件并按其中 Prompt / guardrails 执行；与本文件冲突时以**更严格**者为准。

| Trait | 路径 | 何时强制 |
|-------|------|----------|
| effort-token-estimate | `traits/effort-token-estimate-trait.md` | 调研工作量评估；创建/更新 change 的 `.openspec.yaml`；用户问及工作量 / effort / 落地规模 |
| intake-parking | `traits/intake-parking-trait.md` | 挂起/碎片需求；`/intake-draft` · `/intake-register` · `/intake-promote`；超出当前 change 范围先收件 |
| avalonia-docs | `traits/avalonia-docs-trait.md` | Avalonia UI / AXAML / 绑定 / 样式 / DevTools / WPF 迁移；涉及 `repos/MaterialClient` 界面实现 |
| type-owned-methods | `traits/type-owned-methods-trait.md` | C# 类型归属变更与投影；Service 禁止字段赋值；OpenSpec 转化/变更 API 草图 |
| minimal-di | `traits/minimal-di-trait.md` | C# 新建类型/DI 注册；禁止纯逻辑注册为 Transient/Singleton；OpenSpec 中 Service 提案 |
| no-database-fk | `traits/no-database-fk-trait.md` | 实体 / Fluent / migration / SQL；表间关联与跨 Context 数据组合 |
| viewmodel-no-repository | `traits/viewmodel-no-repository-trait.md` | ViewModel / Blazor / 界面层访问数据；禁止 UI 注入 Repository 或 DbContext |
| openspec-git-workflow | `traits/openspec-git-workflow.md` | OpenSpec Propose / Apply / Archive；跨仓同名分支、squash 合入、`dev-*` promote；merge-check |

### effort-token-estimate（硬约束摘要）

- 工作量用 **S/M/L/XL + token 量级**，**禁止**以人天 / 人周作为主指标。
- 用途仅作**调研与开 change 前的估算参考**；不强制记录实耗 token。
- OpenSpec 中 effort **只写** `openspec/changes/<name>/.openspec.yaml` 的 `effort:` 块。
- **禁止**把 effort / 工期 / token 估算写进 `proposal.md`（以及 design / specs / tasks）。

完整规则、档位表与 yaml 示例见 `traits/effort-token-estimate-trait.md`。

### intake-parking（硬约束摘要）

- Draft（草稿纸）**不占**全局 INT 序号；正式种子用 `docs/intake/<YYYY-MM>/INT-00N-*.md`，序号**全局**递增。
- 业务 theme / park / 仓库列表只读 **`docs/intake/themes.md`**、**`docs/intake/parks.md`**（项目绑定）；**禁止**写进可迁移的 trait 文件。
- 晋升后源 draft：**archive** 或 **delete**（默认 archive）。
- 消化按 **theme**；挂起月勿空占 Epic / 勿为记账而 propose。

完整机制、迁移清单见 `traits/intake-parking-trait.md`。本地设计决策记录见 `docs/2026-08-27-intake-parking/`。

### avalonia-docs（硬约束摘要）

- Avalonia **不是** WPF：禁止用 WPF 习惯（Triggers、`DependencyProperty`、`pack://`、`Visibility` 枚举等）凭记忆硬套。
- 涉及 AXAML / 控件 / 样式 / 绑定时：先读 MCP `avalonia-docs`（`get_avalonia_expert_rules` / `search_avalonia_docs` / `lookup_avalonia_api`）。
- **文档查证**用 avalonia-docs；**运行时检视**用 `avalonia_devtools`——二者勿混用。
- 与子仓库 `AGENTS.md` 冲突时以**更具体**者为准（如 MaterialClient 继续用 ReactiveUI / Semi·Ursa，不因 MCP 默认 CommunityToolkit 而擅自换栈）。

完整工具路由与优先级见 `traits/avalonia-docs-trait.md`。

### type-owned-methods（硬约束摘要）

- **变更（mutation）**：Entity、DTO、envelope、form 等由**类型自身实例方法**改状态（如 `waybill.ConfirmReceiving(...)`、`envelope.EnableMode(...)`）；Service / ViewModel **禁止**逐字段赋值。
- **投影（projection）**：跨类型只读转换用静态 **`From*`**（目标类型 canonical）与 **`To*`**（源扩展，须委托 `From*`），例如 `RecycleTransportRecord.FromWaybill(...)`。
- **禁止**新增 `IXxxMapper` / `XxxMapper` / 映射 Service，也**禁止**为转化注册 DI；领域实体不得依赖外部契约 DTO 形状。
- 查表等上下文作为方法参数或 Context `record`，不作为 mapper 构造注入。
- 无明确要求时，不把存量 mapper 清扫塞进当前 change；**触及** Service 内字段赋值时应在该 change 内迁到类型归属方法。

完整规则与正反例见 `traits/type-owned-methods-trait.md`（原 `static-from-to`）。

### minimal-di（硬约束摘要）

- 新类型 **默认不注册 DI**；仅当需要 Repository、外部 I/O、ABP 基础设施角色、生命周期状态，或子仓 UI 约定（ViewModel/Window 等）时才 `ITransientDependency` / `ISingletonDependency`。
- **禁止**将纯映射、格式化、校验、Helper 注册为 Service（`*HelperService`、`*MappingService`、无 I/O 的 `*ConverterService`）。
- 纯逻辑用 static / extension / type-owned 方法；与 `type-owned-methods` 同时生效。
- OpenSpec `tasks.md` 不得写「实现 XxxService 并注册 DI」除非满足注册门槛。

完整决策树与正反例见 `traits/minimal-di-trait.md`。

### no-database-fk（硬约束摘要）

- 表间只用逻辑 **`{Related}Id`** 列；**禁止**数据库外键、EF `HasForeignKey` / `HasOne`/`HasMany`、实体上的 `[ForeignKey]` 与为关系服务的导航属性。
- 关联数据在 **Service** 中二次查询或查表后组合；需要原子写时共用连接/事务，不靠引擎 FK。
- 内核与产品 Context 之间同样 **禁止跨 Context FK**。
- 无明确要求时，不把存量引擎外键清扫塞进当前 change。

完整规则与正反例见 `traits/no-database-fk-trait.md`。

### viewmodel-no-repository（硬约束摘要）

- 界面层（ViewModel、Avalonia code-behind、等价 Blazor 组件）**禁止**注入或调用 `IRepository` / `DbContext`。
- 数据访问：**View → ViewModel → Service → Repository → DbContext**；缺 Service 时按 `minimal-di` 新建 Service，不得把 Repository 接到 UI。
- Service **写操作**必须 `[UnitOfWork]`；Service **不得**注入 ViewModel。
- **禁止**把本规则再写进子仓库 `AGENTS.md`；以本 trait 为准。

完整规则与正反例见 `traits/viewmodel-no-repository-trait.md`。

### openspec-git-workflow（硬约束摘要）

- 未声明 initiative 时用 **Mode A**（change 同名分支自 trunk 切出，squash 回 trunk）；Mode B 须在 `proposal.md` / `tasks.md` 写明 `dev-<initiative>`。
- Apply **首次改该仓代码前**切到与 change 同名的分支；无实际改动的仓不建分支。
- 合入目标分支 **MUST squash 单提交**；禁止 `--no-ff` merge；禁止在 trunk / `dev-*` 上直接堆功能 commit。
- Archive **默认** sync delta → `openspec/specs/`，不要询问；合入后跑 merge-check 并切回 trunk（Mode B promote 后必须回 trunk）。
- 本仓主干以 `origin/HEAD` 为准（monospec 多为 `main`，多数子仓多为 `master`）。

完整规则、模式图与检查清单见 `traits/openspec-git-workflow.md`。

## OpenSpec 与技术债务

> **默认规则：除非用户或当前 change 的 proposal 明确要求，否则不要在 OpenSpec 流程中处理技术债务。**

### 默认不做（无明确要求时）

在 **propose、specs、design、tasks、apply、archive** 全过程中：

- 不将技术债务清理、大范围重构、「顺手」优化写入 `proposal.md` / `design.md` / `tasks.md`
- 不借机修改与当前 change **Why / What Changes** 无关的代码、目录结构或命名
- 不在 apply 阶段以「提高质量」「统一风格」「顺便整理」为由扩大实现范围

### 仅在以下情况可包含技术债务

- 用户在对话或需求中**明确要求**处理某项技术债务；或
- **proposal.md** 的 What Changes / Capabilities / Impact 中**明确列出**该技术债务项

若技术债务工作量大或与业务变更可分离，应**单独创建 change**（如 `refactor-*`），不要塞进当前功能 change。

### 发现技术债务时

- 可在对话中**简短备注**（可选），但不要自动加入当前 change 的 tasks
- 建议用户另开 change 或记入 backlog，待显式授权后再走 OpenSpec

## 最佳实践

- 所有非平凡的变更都应通过 OpenSpec 提案流程
- **所有 OpenSpec 工件只能在主仓库 `openspec/` 中创建，禁止在 `repos/` 子项目中生成**（参见「OpenSpec 生成位置约束」）
- 跨仓库的变更应在提案中明确说明影响的子仓库
- 代码实现完成后，更新 tasks.md 中的完成状态
- 保持 specs 与代码实现同步
- 变更名称使用动词引导（add-、update-、remove-、refactor-）
- 归档前确认所有任务已完成
- 定期运行验证脚本确保配置正确
- **无明确要求时，OpenSpec 不处理技术债务**（参见「OpenSpec 与技术债务」）
- **界面层不得碰 Repository**（viewmodel-no-repository；**不要**写入子仓 `AGENTS.md`）
- **禁止使用 tuple 作为 API/字段类型；多值组合使用命名 `record`**（参见「跨子仓库 C# 编码约定」）
- **工作量评估遵循 effort-token-estimate；effort 仅写入 `.openspec.yaml`，禁止进入 `proposal.md`**（参见「Required traits」）
- **挂起/碎片需求遵循 intake-parking；业务 theme/park 仅写在 `docs/intake/themes.md` / `parks.md`，禁止写进可迁移 trait**（参见「Required traits」）
- **Avalonia UI 工作遵循 avalonia-docs；先查 MCP 文档，再实现；与子仓库 AGENTS 冲突时以更具体者为准**（参见「Required traits」）
- **类型归属变更与投影遵循 type-owned-methods；Service 禁止字段赋值；禁止新增 mapper 类型或为映射注册 DI**（参见「Required traits」）
- **DI 注册遵循 minimal-di；纯逻辑不得注册为 Transient/Singleton；新建 Service 须过注册门槛**（参见「Required traits」）
- **禁止数据库外键与 EF 关系映射；逻辑 Id + Service 组合**（参见「Required traits」）
- **OpenSpec 分支与合入遵循 openspec-git-workflow；默认 Mode A + squash 单提交，禁止在目标分支直接开发**（参见「Required traits」）
