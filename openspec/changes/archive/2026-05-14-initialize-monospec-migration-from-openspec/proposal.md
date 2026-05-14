# 变更提案: OpenSpec 到 Monospec 迁移初始化

## Why

MaterialClient 和 UrbanManagement 项目当前使用独立的 OpenSpec 格式管理文档，缺乏统一的跨仓库变更管理视图，导致文档分散、维护成本高，且难以追踪跨项目的依赖关系。通过迁移到 Monospec 格式，可以在主仓库统一管理所有子仓库的变更文档，提升标准化程度和协作效率。

## What Changes

- **创建 Monospec 主仓库结构**：建立 MaterialMonospec 作为统一文档管理中心
- **配置 monospecs.yaml**：创建标准化的多仓库配置文件，使用相对路径管理子仓库
- **迁移现有 specs**：将 MaterialClient 的 46 个 specs 和 UrbanManagement 的 6 个 specs 迁移到主仓库
- **重组目录结构**：按照 Monospec 规范重新组织 openspec/ 目录
- **建立配置模板**：创建可复用的 monospecs.yaml 配置模板，供未来项目参考
- **配置自动化**：设置 `commit_when_archive` 选项实现 specs 自动提交
- **保持历史记录**：将子仓库中的归档变更迁移到主仓库的 changes/archive/ 目录

## Capabilities

### New Capabilities

- **monospec-repository-layout**: 定义主仓库的目录结构和配置文件规范，确保符合 Monospec 标准
- **openspec-migration-utility**: 提供从独立 OpenSpec 仓库到 Monospec 主仓库的迁移工具和流程
- **unified-change-management**: 建立跨仓库变更管理的统一视图和工作流
- **monospec-config-template**: 创建可复用的 monospecs.yaml 配置模板，包含标准化的仓库元数据字段

### Modified Capabilities

_无现有 capabilities 需要修改。这是新的 Monospec 仓库初始化。_

## Impact

**受影响的系统**：
- MaterialClient: openspec/ 目录将被移除，specs 文档迁移到主仓库
- UrbanManagement: openspec/ 目录将被移除，specs 文档迁移到主仓库
- MaterialMonospec: 新建主仓库，成为统一的文档管理中心

**文档结构变化**：
- 子仓库的 openspec/specs/ → 主仓库的 openspec/specs/
- 子仓库的 openspec/changes/archive/ → 主仓库的 openspec/changes/archive/

**工作流程变化**：
- 所有变更的 proposal、design、specs、tasks 文档在主仓库创建
- 代码变更仍在子仓库中进行
- 归档操作自动提交 specs 到主仓库（commit_when_archive: true）

**开发体验提升**：
- 统一的变更管理入口
- 跨仓库依赖关系可视化
- 标准化的配置模板
