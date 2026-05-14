# OpenSpec Migration Utility

提供从独立 OpenSpec 仓库到 Monospec 主仓库的迁移工具和流程。

## ADDED Requirements

### Requirement: Spec migration capability
系统 SHALL 提供将子仓库 `openspec/specs/` 目录下的所有 spec 文件迁移到主仓库 `openspec/specs/` 的能力。

#### Scenario: Migrating MaterialClient specs
- **WHEN** 执行 MaterialClient specs 迁移操作
- **THEN** SHALL 将 `../MaterialClient/openspec/specs/` 下的所有 46 个 spec 目录复制到主仓库 `openspec/specs/`
- **AND** SHALL 保持原有的目录结构和文件名
- **AND** SHALL 验证每个 spec.md 文件的完整性

#### Scenario: Migrating UrbanManagement specs
- **WHEN** 执行 UrbanManagement specs 迁移操作
- **THEN** SHALL 将 `../UrbanManagement/openspec/specs/` 下的所有 6 个 spec 目录复制到主仓库 `openspec/specs/`
- **AND** SHALL 保持原有的目录结构和文件名

### Requirement: Archived changes migration
系统 SHALL 提供将子仓库 `openspec/changes/archive/` 目录下的所有归档变更迁移到主仓库的能力。

#### Scenario: Migrating archived changes
- **WHEN** 执行归档变更迁移操作
- **THEN** SHALL 将子仓库的 `changes/archive/` 目录内容合并到主仓库 `openspec/changes/archive/`
- **AND** SHALL 保持时间戳目录命名格式（如 `2026-01-15-md-milestone-document-organization`）
- **AND** SHALL 处理可能的文件名冲突（添加仓库名称前缀）

### Requirement: Subrepository cleanup
迁移完成后，系统 SHALL 从子仓库中移除 `openspec/` 目录，确保子仓库保持纯净。

#### Scenario: Cleaning up MaterialClient
- **WHEN** MaterialClient specs 迁移完成并验证
- **THEN** SHALL 删除 `../MaterialClient/openspec/` 目录
- **AND** SHALL 更新 `.gitignore` 移除相关规则（如存在）

#### Scenario: Cleaning up UrbanManagement
- **WHEN** UrbanManagement specs 迁移完成并验证
- **THEN** SHALL 删除 `../UrbanManagement/openspec/` 目录
- **AND** SHALL 更新 `.gitignore` 移除相关规则

### Requirement: Migration verification
系统 SHALL 提供验证机制，确保所有 specs 和归档变更已成功迁移且内容完整。

#### Scenario: Verifying migration completeness
- **WHEN** 执行迁移验证操作
- **THEN** SHALL 对比源目录和目标目录的 spec 文件数量
- **AND** SHALL 验证每个 spec.md 文件的内容完整性
- **AND** SHALL 报告任何迁移失败或内容不匹配的情况
