# Unified Change Management

建立跨仓库变更管理的统一视图和工作流。

## ADDED Requirements

### Requirement: Centralized change creation
所有新的变更（proposal、design、specs、tasks）SHALL 在主仓库的 `openspec/changes/` 目录中创建，而非在子仓库中。

#### Scenario: Creating new change
- **WHEN** 开发者需要创建涉及 MaterialClient 或 UrbanManagement 的新变更
- **THEN** SHALL 在主仓库 `openspec/changes/<change-name>/` 创建变更目录
- **AND** SHALL 在变更目录中创建 proposal.md、design.md、specs、tasks.md 文件
- **AND** SHALL 在变更中注明影响的子仓库（如 MaterialClient、UrbanManagement）

### Requirement: Cross-repository change tracking
变更管理系统 SHALL 能够追踪哪些变更涉及多个子仓库，并提供依赖关系可视化。

#### Scenario: Tracking multi-repo change
- **WHEN** 变更涉及 MaterialClient 和 UrbanManagement 两个仓库
- **THEN** SHALL 在 proposal.md 的 Impact 部分明确列出受影响的子仓库
- **AND** SHALL 在 tasks.md 中按子仓库分组任务
- **AND** SHALL 提供跨仓库的依赖关系视图

### Requirement: Automated spec archiving
当设置 `commit_when_archive: true` 时，归档操作 SHALL 自动将 specs 提交到主仓库，无需手动操作。

#### Scenario: Auto-committing specs on archive
- **WHEN** 变更完成并执行归档操作
- **THEN** SHALL 系统自动将 proposal.md、design.md、specs、tasks.md 提交到主仓库的 git
- **AND** SHALL 使用规范的提交消息格式
- **AND** SHALL 不包含子仓库的代码变更（子仓库代码仍需单独提交）

### Requirement: Change visibility across repositories
主仓库 SHALL 提供统一的变更历史视图，涵盖所有子仓库的变更记录。

#### Scenario: Viewing all changes
- **WHEN** 开发者查看主仓库的变更历史
- **THEN** SHALL 能够看到涉及 MaterialClient 的所有变更
- **AND** SHALL 能够看到涉及 UrbanManagement 的所有变更
- **AND** SHALL 能够按时间、仓库、状态等维度筛选变更

### Requirement: Implementation location separation
变更文档在主仓库管理，但代码实现 SHALL 仍在各子仓库的代码目录中进行。

#### Scenario: Implementing change code
- **WHEN** 开发者实现变更中的代码部分
- **THEN** SHALL 在 `repos/MaterialClient/` 或 `repos/UrbanManagement/` 中修改代码
- **AND** SHALL 在主仓库的 tasks.md 中追踪实现进度
- **AND** SHALL 代码提交在子仓库的 git 中独立进行
