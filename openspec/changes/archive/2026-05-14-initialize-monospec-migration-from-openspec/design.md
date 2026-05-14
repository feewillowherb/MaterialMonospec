# 设计文档: OpenSpec 到 Monospec 迁移

## Context

### 当前状态

MaterialClient 和 UrbanManagement 两个项目目前各自独立使用 OpenSpec 格式管理文档：

```
当前架构
├── ../MaterialClient/
│   ├── openspec/
│   │   ├── specs/ (46个规格)
│   │   ├── changes/
│   │   │   └── archive/ (大量归档变更)
│   │   ├── PROPOSAL_DESIGN_GUIDELINES.md
│   │   └── project.md
│   └── [项目代码]
│
└── ../UrbanManagement/
    ├── openspec/
    │   ├── specs/ (6个规格)
    │   └── changes/
    │       └── archive/ (2个归档变更)
    └── [项目代码]
```

### 问题

1. **文档分散**：每个仓库独立管理文档，缺乏统一视图
2. **跨仓库协作困难**：无法追踪涉及多个仓库的变更依赖关系
3. **维护成本高**：需要在多个仓库中维护相似的文档结构
4. **历史记录孤立**：归档的变更分散在各仓库中，难以跨项目查询

### 约束

- **保持历史记录**：不能丢失现有的 specs 和归档变更
- **最小化中断**：迁移过程应尽量减少对现有开发流程的影响
- **工具兼容性**：需要确保 OpenSpec 工具链能正常工作

## Goals / Non-Goals

**Goals:**
- 建立 MaterialMonospec 主仓库作为统一文档管理中心
- 迁移所有现有的 specs 和归档变更到主仓库
- 创建标准化的 monospecs.yaml 配置模板
- 实现自动化的 specs 提交机制（commit_when_archive）
- 保持子仓库的代码和功能完全不变

**Non-Goals:**
- 不修改子仓库的代码逻辑或功能
- 不改变现有的 specs 内容和格式
- 不涉及其他非 MaterialClient/UrbanManagement 项目的迁移
- 不包含文档内容的重写或优化

## Decisions

### 决策 1: 使用相对路径配置 monospecs.yaml

**选择**：在 `monospecs.yaml` 中使用相对路径（`repos/MaterialClient`）而非绝对路径。

**理由**：
- ✅ 跨平台兼容性（Windows/Linux/macOS）
- ✅ 仓库可以整体移动而不破坏配置
- ✅ 更容易在不同开发者机器上设置
- ✅ 符合 Monospec 规范约定

**替代方案**：使用绝对路径
- ❌ 平台依赖性强
- ❌ 仓库移动后需要更新配置
- ❌ 每个开发者需要调整路径

**配置示例**：
```yaml
version: "1.0"
repo_dir: repos
commit_when_archive: true
repositories:
  - path: repos/MaterialClient
    url: https://github.com/feewillowherb/MaterialClient.git
    displayName: MaterialClient
    type: Desktop
    optional: false
    tags: [avalonia, industrial]
  - path: repos/UrbanManagement
    url: https://github.com/feewillowherb/UrbanManagement.git
    displayName: UrbanManagement
    type: WebServer
    optional: false
    tags: [abp, web]
```

### 决策 2: 渐进式迁移策略

**选择**：先迁移 UrbanManagement（试点），验证流程后再迁移 MaterialClient。

**理由**：
- ✅ UrbanManagement 规模小（6个 specs），风险低
- ✅ 可以在试点阶段发现和修复问题
- ✅ MaterialClient 更复杂（46个 specs），需要验证的流程
- ✅ 可以逐步完善迁移工具和文档

**替代方案**：同时迁移两个项目
- ❌ 风险高，难以定位问题
- ❌ 回滚困难
- ❌ 需要更多准备和测试

**迁移阶段**：
```
阶段 1: UrbanManagement 迁移（试点）
├── 验证配置模板
├── 测试迁移工具
├── 验证 OpenSpec 工具链
└── 完善文档和流程

阶段 2: MaterialClient 迁移
├── 应用已验证的流程
├── 处理大规模数据迁移
└── 验证历史记录完整性
```

### 决策 3: 保持归档变更的原始结构

**选择**：迁移归档变更时保持原有的时间戳目录命名和内部结构。

**理由**：
- ✅ 保持历史记录的可追溯性
- ✅ 最小化对现有工具的影响
- ✅ 便于开发者查找历史变更

**目录结构**：
```
openspec/changes/archive/
├── 2026-01-15-md-milestone-document-organization/
├── 2026-01-28-hikvision-lpr-integration/
├── 2026-03-03-view-files-categorization/
└── ...
```

### 决策 4: 启用 commit_when_archive 自动提交

**选择**：设置 `commit_when_archive: true` 实现归档时自动提交 specs。

**理由**：
- ✅ 简化工作流程，减少手动操作
- ✅ 确保 specs 与代码变更同步
- ✅ 避免 specs 遗漏提交的问题

**注意事项**：
- 子仓库的代码变更仍需手动提交
- 自动提交只针对 proposal、design、specs、tasks 文档

## 组件架构

```
MaterialMonospec 主仓库组件层次结构
│
├── openspec/ (OpenSpec 变更管理)
│   ├── changes/ (变更目录)
│   │   ├── initialize-monospec-migration-from-openspec/ (活动变更)
│   │   │   ├── proposal.md
│   │   │   ├── design.md
│   │   │   ├── specs/
│   │   │   │   ├── monospec-repository-layout/
│   │   │   │   ├── openspec-migration-utility/
│   │   │   │   ├── unified-change-management/
│   │   │   │   └── monospec-config-template/
│   │   │   └── tasks.md
│   │   └── archive/ (归档变更)
│   │       ├── urbanmanagement-initialization/
│   │       └── mock-frontend-migration/
│   └── specs/ (规范定义)
│       ├── attended-weighing/ (从 MaterialClient 迁移)
│       ├── license-plate-recognition/ (从 MaterialClient 迁移)
│       ├── abp-project-init/ (从 UrbanManagement 迁移)
│       └── ...
│
├── repos/ (子仓库目录)
│   ├── MaterialClient/ (子仓库，无 openspec/)
│   │   ├── MaterialClient/
│   │   ├── MaterialClient.Common/
│   │   └── [其他项目目录]
│   └── UrbanManagement/ (子仓库，无 openspec/)
│       ├── src/
│       └── tests/
│
├── monospecs.yaml (Monospec 配置文件)
└── .gitignore (排除 repos/ 目录)
```

## 数据流

```
OpenSpec 迁移数据流图

┌─────────────────────────────────────────────────────────────────┐
│ 阶段 1: 迁移准备                                                │
└─────────────────────────────────────────────────────────────────┘
     │
     ├──► 读取 ../MaterialClient/openspec/specs/
     │    └── 扫描 46 个 spec 目录
     │
     ├──► 读取 ../UrbanManagement/openspec/specs/
     │    └── 扫描 6 个 spec 目录
     │
     └──► 读取归档变更目录
          └── 收集所有 archive/ 下的变更

┌─────────────────────────────────────────────────────────────────┐
│ 阶段 2: 执行迁移                                                │
└─────────────────────────────────────────────────────────────────┘
     │
     ├──► 复制 specs 到主仓库
     │    └── openspec/specs/
     │
     ├──► 合并归档变更
     │    └── openspec/changes/archive/
     │        └── 处理文件名冲突
     │
     └──► 验证完整性
          └── 对比源和目标文件数量

┌─────────────────────────────────────────────────────────────────┐
│ 阶段 3: 清理子仓库                                              │
└─────────────────────────────────────────────────────────────────┘
     │
     ├──► 删除 ../MaterialClient/openspec/
     │
     ├──► 删除 ../UrbanManagement/openspec/
     │
     └──► 更新 .gitignore

┌─────────────────────────────────────────────────────────────────┐
│ 阶段 4: 后续开发工作流                                          │
└─────────────────────────────────────────────────────────────────┘
     │
     ├──► 创建变更
     │    └── openspec/changes/<change-name>/
     │
     ├──► 实现代码
     │    └── repos/MaterialClient/ 或 repos/UrbanManagement/
     │
     └──► 归档变更
          └── 自动提交 specs 到主仓库 (commit_when_archive: true)
```

## API 调用时序

```
OpenSpec 迁移和变更管理时序图

participant Dev as 开发者
participant Main as 主仓库
participant MC as MaterialClient
participant UM as UrbanManagement
participant Tool as OpenSpec CLI

Dev->>Main: 创建 monospecs.yaml 配置
Main->>Tool: 验证配置格式
Tool-->>Main: 配置有效

Dev->>Tool: 执行迁移命令
Tool->>MC: 读取 openspec/specs/ (46个)
MC-->>Tool: 返回 spec 文件列表
Tool->>Main: 复制到 openspec/specs/
Tool->>MC: 读取 openspec/changes/archive/
MC-->>Tool: 返回归档变更列表
Tool->>Main: 合并到 changes/archive/

Dev->>Tool: 验证迁移完整性
Tool->>Main: 对比文件数量
Tool->>MC: 删除 openspec/ 目录
Tool->>UM: 删除 openspec/ 目录

Dev->>Main: 创建新变更 openspec/changes/add-feature/
Dev->>Tool: 生成变更工件
Tool-->>Main: 创建 proposal、design、specs、tasks

Dev->>MC: 在 repos/MaterialClient/ 实现代码
Dev->>Tool: 归档变更
Tool->>Main: 自动提交 specs (commit_when_archive)
Main-->>Dev: 提交完成，代码需单独提交
```

## 详细代码变更清单

| 文件路径 | 变更类型 | 变更说明 | 影响模块 |
|---------|---------|---------|---------|
| `monospecs.yaml` | 新增 | 创建 Monospec 配置文件，定义子仓库信息 | 主仓库配置 |
| `.gitignore` | 修改 | 添加 `repos/` 排除规则 | 版本控制 |
| `openspec/specs/*` | 新增 | 从子仓库迁移 52 个 spec 目录 | 规范定义 |
| `openspec/changes/archive/*` | 新增 | 从子仓库迁移所有归档变更 | 变更历史 |
| `../MaterialClient/openspec/` | 删除 | 移除 OpenSpec 目录，子仓库保持纯净 | MaterialClient |
| `../UrbanManagement/openspec/` | 删除 | 移除 OpenSpec 目录，子仓库保持纯净 | UrbanManagement |
| `AGENTS.md` | 新增 | 创建主仓库的 Agent 配置文件 | 开发者体验 |

## Risks / Trade-offs

### 风险 1: 迁移过程中数据丢失
**描述**：大量 specs 和归档变更迁移可能导致文件丢失或损坏。

**缓解措施**：
- 迁移前备份整个 openspec/ 目录
- 使用验证工具对比源和目标的文件数量和内容
- 采用渐进式迁移，先试点再全面推广
- 保留子仓库的 git 历史，可以随时恢复

### 风险 2: OpenSpec 工具链兼容性
**描述**：现有 OpenSpec CLI 工具可能不兼容 Monospec 结构。

**缓解措施**：
- 在 UrbanManagement 试点阶段验证工具兼容性
- 如发现问题，与 OpenSpec 团队协调修复
- 准备手动操作脚本作为备用方案

### 风险 3: 开发者学习曲线
**描述**：开发者需要适应新的工作流程和目录结构。

**缓解措施**：
- 创建详细的迁移指南和最佳实践文档
- 组织团队培训，介绍新的工作流程
- 在 AGENTS.md 中提供清晰的指引
- 设置过渡期，两种方式并存

### 权衡 1: 配置复杂度 vs 灵活性
**选择**：使用标准化的 monospecs.yaml 配置，增加了一定复杂度。

**理由**：标准化带来的长期收益（可维护性、可扩展性）超过了短期的学习成本。

### 权衡 2: 迁移工作量 vs 立即收益
**选择**：投入时间进行完整迁移，包括历史记录。

**理由**：保持历史记录的完整性对于项目长期维护非常重要，一次性迁移可以避免未来的技术债务。

## Migration Plan

### 阶段 1: 准备工作（1-2 天）

1. **创建主仓库结构**
   - 初始化 MaterialMonospec git 仓库
   - 创建 openspec/、repos/ 目录
   - 配置 .gitignore

2. **配置 monospecs.yaml**
   - 定义子仓库配置（使用相对路径）
   - 验证 YAML 语法和必需字段
   - 测试 OpenSpec CLI 工具兼容性

3. **备份现有数据**
   - 备份 MaterialClient openspec/ 目录
   - 备份 UrbanManagement openspec/ 目录

### 阶段 2: UrbanManagement 迁移（试点，1 天）

1. **迁移 specs**
   ```bash
   cp -r ../UrbanManagement/openspec/specs/* openspec/specs/
   ```

2. **迁移归档变更**
   ```bash
   cp -r ../UrbanManagement/openspec/changes/archive/* openspec/changes/archive/
   ```

3. **验证完整性**
   - 对比 spec 数量（应为 6 个）
   - 验证归档变更数量

4. **清理子仓库**
   ```bash
   rm -rf ../UrbanManagement/openspec/
   ```

5. **测试工作流**
   - 创建测试变更
   - 验证 commit_when_archive 功能
   - 确认 OpenSpec CLI 工具正常工作

### 阶段 3: MaterialClient 迁移（2-3 天）

1. **迁移 specs**
   - 复制 46 个 spec 目录到主仓库
   - 验证每个 spec.md 的完整性

2. **迁移归档变更**
   - 合并大量归档变更到主仓库
   - 处理可能的文件名冲突（添加仓库名称前缀）

3. **验证完整性**
   - 对比 spec 数量（应为 46 个）
   - 验证归档变更数量和内容

4. **清理子仓库**
   ```bash
   rm -rf ../MaterialClient/openspec/
   ```

5. **迁移项目文档**
   - 复制 PROPOSAL_DESIGN_GUIDELINES.md 到主仓库
   - 复制 project.md 内容并整合到 AGENTS.md

### 阶段 4: 完善和文档（1 天）

1. **创建配置模板**
   - 编写 monospecs.yaml 配置指南
   - 创建子仓库添加模板

2. **更新文档**
   - 创建迁移指南文档
   - 更新 AGENTS.md 说明新工作流程
   - 编写故障排除指南

3. **团队培训**
   - 介绍新的 Monospec 工作流程
   - 演示变更创建和归档流程
   - 解答疑问和收集反馈

### 回滚策略

如果迁移过程中遇到严重问题：

1. **阶段 2 回滚**：从 git 备份恢复 UrbanManagement
2. **阶段 3 回滚**：从 git 备份恢复 MaterialClient
3. **完全回滚**：删除主仓库，恢复原有独立管理方式

## Open Questions

1. **归档变更文件名冲突**：如果 MaterialClient 和 UrbanManagement 有相同日期的变更，如何处理？
   - **倾向方案**：添加仓库名称前缀，如 `2026-01-15-materialclient-doc-org` 和 `2026-01-15-urbanmanagement-init`

2. **commit_when_archive 性能**：对于大型变更，自动提交是否会明显变慢？
   - **需要测试**：在阶段 2 试点时评估性能

3. **子仓库 CI/CD 集成**：子仓库的 CI/CD 流程是否需要调整？
   - **待研究**：当前变更不涉及 CI/CD，后续可能需要

4. **HagiCode 桌面应用支持**：是否需要使用 HagiCode 应用辅助管理？
   - **可选**：当前使用命令行工具足够，HagiCode 作为未来优化选项
