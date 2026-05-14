# Monospec Repository Layout

定义主仓库的目录结构和配置文件规范，确保符合 Monospec 标准。

## ADDED Requirements

### Requirement: Root directory structure
主仓库 SHALL 包含以下顶层目录和文件：`monospecs.yaml`、`openspec/`、`repos/`、`.gitignore`。

#### Scenario: Validating root structure exists
- **WHEN** 检查主仓库根目录
- **THEN** SHALL 存在 `monospecs.yaml` 配置文件
- **AND** SHALL 存在 `openspec/` 目录用于变更管理
- **AND** SHALL 存在 `repos/` 目录用于子仓库
- **AND** SHALL 存在 `.gitignore` 文件排除 `repos/` 目录

### Requirement: Openspec directory organization
主仓库的 `openspec/` 目录 SHALL 包含 `changes/` 和 `specs/` 子目录，分别用于变更管理和规范定义。

#### Scenario: Validating openspec structure
- **WHEN** 检查 `openspec/` 目录结构
- **THEN** SHALL 存在 `openspec/changes/` 目录
- **AND** SHALL 存在 `openspec/specs/` 目录
- **AND** `openspec/changes/` SHALL 包含活动变更和归档变更

### Requirement: Gitignore configuration
`.gitignore` 文件 SHALL 明确排除 `repos/` 目录，但保留 `monospecs.yaml` 和 `openspec/` 目录。

#### Scenario: Validating gitignore excludes repos
- **WHEN** 读取 `.gitignore` 文件内容
- **THEN** SHALL 包含 `repos/` 排除规则
- **AND** SHALL 不排除 `monospecs.yaml`
- **AND** SHALL 不排除 `openspec/` 目录

### Requirement: Subrepository purity
子仓库（在 `repos/` 目录下）SHALL NOT 包含自己的 `openspec/` 目录，所有 OpenSpec 内容由主仓库管理。

#### Scenario: Validating subrepository has no openspec
- **WHEN** 检查 `repos/MaterialClient/` 或 `repos/UrbanManagement/` 目录
- **THEN** SHALL NOT 存在 `openspec/` 子目录
- **AND** 子仓库 SHALL 只包含项目代码和配置文件
