# MaterialMonospec - Agent 行为准则

## 项目概述

MaterialMonospec 是一个 Monospec 主仓库，统一管理 MaterialClient（工业材料称重桌面应用）和 UrbanManagement（城市管理 Web 应用）两个子仓库的 OpenSpec 文档。所有变更的 proposal、design、specs、tasks 在主仓库中创建和管理，代码实现仍在各自的子仓库中进行。

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
│   └── UrbanManagement/                  # ABP Web 应用
├── docs/                                 # 文档
│   ├── monospecs-yaml-template.md        # 配置模板
│   ├── add-repo-guide.md                 # 添加子仓库指南
│   ├── migration-guide.md                # 迁移指南
│   └── troubleshooting.md               # 故障排除
├── scripts/                              # 工具脚本
│   ├── validate-config.ps1               # 配置验证
│   └── validate-migration.ps1            # 迁移验证
├── monospecs.yaml                        # Monospec 配置
├── PROPOSAL_DESIGN_GUIDELINES.md         # 提案设计指南
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

主仓库使用 `monospecs.yaml` 配置子仓库信息：

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

## 工具和验证

```bash
# 验证配置文件
powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1

# 验证迁移完整性
powershell -ExecutionPolicy Bypass -File scripts/validate-migration.ps1
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

## 最佳实践

- 所有非平凡的变更都应通过 OpenSpec 提案流程
- **所有 OpenSpec 工件只能在主仓库 `openspec/` 中创建，禁止在 `repos/` 子项目中生成**（参见「OpenSpec 生成位置约束」）
- 跨仓库的变更应在提案中明确说明影响的子仓库
- 代码实现完成后，更新 tasks.md 中的完成状态
- 保持 specs 与代码实现同步
- 变更名称使用动词引导（add-、update-、remove-、refactor-）
- 归档前确认所有任务已完成
- 定期运行验证脚本确保配置正确
