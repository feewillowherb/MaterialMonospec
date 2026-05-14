# Monospec Config Template

创建可复用的 monospecs.yaml 配置模板，包含标准化的仓库元数据字段。

## ADDED Requirements

### Requirement: Standardized monospecs.yaml structure
`monospecs.yaml` 配置文件 SHALL 遵循标准化的结构，包含 version、repo_dir、commit_when_archive 和 repositories 字段。

#### Scenario: Validating monospecs.yaml structure
- **WHEN** 读取主仓库的 `monospecs.yaml` 文件
- **THEN** SHALL 包含 `version: "1.0"` 或更高版本
- **AND** SHALL 包含 `repo_dir: "repos"` 指定子仓库目录
- **AND** SHALL 包含 `commit_when_archive: true` 启用自动提交
- **AND** SHALL 包含 `repositories:` 数组列出所有子仓库

### Requirement: Repository metadata fields
每个子仓库配置 SHALL 包含 path、url、displayName、type 和可选的 tags 字段。

#### Scenario: Validating repository configuration
- **WHEN** 检查 repositories 数组中的仓库配置
- **THEN** 每个仓库 SHALL 包含 `path` 字段使用相对路径（如 `repos/MaterialClient`）
- **AND** SHALL 包含 `url` 字段指定 Git 仓库地址
- **AND** SHALL 包含 `displayName` 字段使用简洁的中文名称
- **AND** SHALL 包含 `type` 字段指定仓库类型（Desktop/WebServer/等）
- **AND** MAY 包含 `tags` 数组用于分类和筛选

### Requirement: Relative path convention
仓库路径 SHALL 使用相对于主仓库根目录的路径，而非绝对路径。

#### Scenario: Validating path format
- **WHEN** 检查 repository 的 path 字段
- **THEN** SHALL 使用 `repos/<repo-name>` 格式
- **AND** SHALL NOT 使用绝对路径（如 `C:\Users\...\MaterialClient`）
- **AND** SHALL 使用正斜杠 `/` 作为路径分隔符（跨平台兼容）

### Requirement: Type field enumeration
type 字段 SHALL 从预定义的类型列表中选择：Desktop、WebServer、Library、Mobile、Service、Other。

#### Scenario: Validating type values
- **WHEN** 检查 repository 的 type 字段
- **THEN** SHALL 是以下值之一：Desktop、WebServer、Library、Mobile、Service、Other
- **AND** MaterialClient 的类型 SHALL 为 Desktop
- **AND** UrbanManagement 的类型 SHALL 为 WebServer

### Requirement: Template reusability
配置模板 SHALL 设计为可复用，方便添加新的子仓库而无需修改整体结构。

#### Scenario: Adding new repository
- **WHEN** 需要添加新的子仓库到 monospecs.yaml
- **THEN** SHALL 仅需在 repositories 数组中添加新条目
- **AND** 新条目 SHALL 遵循相同的字段结构
- **AND** SHALL 不影响现有仓库的配置

### Requirement: Configuration validation
系统 SHALL 提供 `monospecs.yaml` 配置验证工具，确保语法正确性和必需字段完整性。

#### Scenario: Validating configuration file
- **WHEN** 执行配置验证操作
- **THEN** SHALL 检查 YAML 语法正确性
- **AND** SHALL 验证所有必需字段存在
- **AND** SHALL 验证 path 字段使用相对路径
- **AND** SHALL 验证 type 字段使用有效值
- **AND** SHALL 报告任何配置错误或警告
