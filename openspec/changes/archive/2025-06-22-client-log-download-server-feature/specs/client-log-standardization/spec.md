# Client Log Standardization Specification

## Purpose

定义 MaterialClient 和 MaterialClient.Urban 客户端的日志文件组织标准化要求，包括日期目录结构、文件大小限制和配置管理，确保服务端可高效定位和拉取日志文件。

## ADDED Requirements

### Requirement: 日志日期目录结构

客户端必须使用日期分层目录结构存储日志文件，格式为 `Logs/{YYYY}/{MM}/{DD}/`。

#### Scenario: 创建日期目录

- **WHEN** 应用启动并初始化日志系统
- **THEN** 系统 SHALL 创建 `Logs/` 根目录（如不存在）
- **AND** Serilog SHALL 自动创建 `{YYYY}/{MM}/{DD}/` 子目录
- **AND** 目录创建失败时抛出 `IOException`

#### Scenario: 日志文件路径格式

- **WHEN** 配置日志文件路径
- **THEN** 路径格式 SHALL 为 `Logs/{YYYY}/{MM}/{DD}/MaterialClient-.log`
- **AND** MaterialClient.Urban 路径格式 SHALL 为 `Logs/{YYYY}/{MM}/{DD}/MaterialClient.Urban-.log`
- **AND** Serilog SHALL 自动替换日期占位符为实际值
- **AND** 文件名自动添加日期后缀（如 `MaterialClient-20250622.log`）

#### Scenario: 日期目录示例

- **假设** 当前日期为 2025-06-22
- **WHEN** 日志文件写入
- **THEN** 完整路径 SHALL 为 `Logs/2025/06/22/MaterialClient-20250622.log`
- **AND** 年份为 4 位数字
- **AND** 月份为 2 位数字（01-12）
- **AND** 日期为 2 位数字（01-31）

### Requirement: 日志文件大小限制

客户端必须启用日志文件大小限制，单文件超过指定大小时自动切割。

#### Scenario: 启用文件大小限制

- **WHEN** 配置 Serilog File sink
- **THEN** 系统 SHALL 设置 `rollOnFileSizeLimit: true`
- **AND** 设置 `fileSizeLimitBytes: 52428800`（50 MB）
- **AND** 配置值从 `appsettings.json` 读取 `Log:FileSizeLimitMB`，默认为 50

#### Scenario: 文件切割命名

- **假设** 单文件大小达到 50 MB
- **WHEN** Serilog 执行文件切割
- **THEN** 新文件名 SHALL 为 `MaterialClient-20250622_001.log`
- **AND** 后续切割文件 SHALL 为 `MaterialClient-20250622_002.log`
- **AND** 序号从 001 开始递增
- **AND** 切割操作不影响日志写入

#### Scenario: 配置大小限制

- **WHEN** 管理员修改 `appsettings.json`
- **THEN** `Log:FileSizeLimitMB` SHALL 接受 10-500 之间的整数值
- **AND** 超出范围时 SHALL 使用默认值 50
- **AND** 配置无效时 SHALL 记录警告日志

### Requirement: 日志保留策略

客户端必须保留指定天数的日志文件，自动删除过期文件。

#### Scenario: 配置保留天数

- **WHEN** 配置 Serilog File sink
- **THEN** 系统 SHALL 设置 `retainedFileCountLimit: 30`
- **AND** 配置值从 `appsettings.json` 读取 `Log:RetentionDays`，默认为 30
- **AND** 值为 0 时 SHALL 保留所有日志

#### Scenario: 自动删除过期日志

- **假设** 保留天数为 30
- **WHEN** 新日志文件创建
- **THEN** Serilog SHALL 检查现有文件数量
- **AND** 删除超过 30 天的日志文件
- **AND** 删除操作 SHALL 优先删除最旧文件
- **AND** 删除失败时 SHALL 记录错误日志但不影响新文件创建

### Requirement: 日志配置可管理性

客户端必须支持通过 `appsettings.json` 管理日志配置，无需修改代码。

#### Scenario: 配置节结构

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 识别 `Log` 配置节
- **AND** 包含 `Enabled` 布尔值（是否启用日志）
- **AND** 包含 `Directory` 字符串（日志目录，默认 "Logs"）
- **AND** 包含 `FileSizeLimitMB` 整数（文件大小限制，默认 50）
- **AND** 包含 `RetentionDays` 整数（保留天数，默认 30）
- **AND** 包含 `UseDateFolders` 布尔值（是否使用日期目录，默认 true）

#### Scenario: 禁用日志功能

- **WHEN** `Log:Enabled` 设置为 `false`
- **THEN** 系统 SHALL 跳过 Serilog 配置
- **AND** 不创建日志目录
- **AND** 不写入日志文件
- **AND** 仍可输出到控制台（如配置）

#### Scenario: 自定义日志目录

- **WHEN** `Log:Directory` 设置为 `/var/log/materialclient`
- **THEN** 系统 SHALL 使用指定目录作为日志根目录
- **AND** 日期子目录 SHALL 在指定目录下创建
- **AND** 目录不存在时 SHALL 自动创建
- **AND** 无权限时 SHALL 抛出 `UnauthorizedAccessException`

### Requirement: 日志文件编码和格式

日志文件必须使用 UTF-8 编码和统一的输出模板。

#### Scenario: UTF-8 编码

- **WHEN** 配置 Serilog File sink
- **THEN** 系统 SHALL 设置 `encoding: Encoding.UTF8`
- **AND** 支持 ASCII 字符和中文等多字节字符
- **AND** 文件头 SHALL 包含 UTF-8 BOM（可选）

#### Scenario: 输出模板格式

- **WHEN** 配置日志输出模板
- **THEN** 系统 SHALL 使用统一格式：`{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}`
- **AND** 时间戳格式为 `2025-06-22 14:30:45.123 +08:00`
- **AND** 日志级别为 3 字符大写（`INF`、`WRN`、`ERR`）
- **AND** 消息内容支持多行
- **AND** 异常堆栈 SHALL 追加在消息后

### Requirement: 向后兼容性

客户端日志标准化必须支持旧日志文件的读取和管理。

#### Scenario: 读取旧路径日志

- **假设** 旧日志文件位于 `Logs/MaterialClient-20250621.log`（无日期目录）
- **WHEN** 服务端请求日志列表
- **THEN** 客户端 SHALL 扫描新旧两种目录结构
- **AND** 返回所有匹配的日志文件
- **AND** 标注文件来源目录结构

#### Scenario: 渐进式迁移

- **假设** 客户端从旧版本升级
- **WHEN** 新版本首次启动
- **THEN** 系统 SHALL 保留旧日志文件在原位置
- **AND** 新日志写入日期目录结构
- **AND** 不迁移或删除旧日志文件
- **AND** 记录迁移提示日志

### Requirement: 日志文件权限和安全性

日志文件必须设置适当的文件权限，防止未授权访问。

#### Scenario: 文件权限设置

- **假设** 运行在 Windows 工控机
- **WHEN** 日志文件创建
- **THEN** 系统 SHALL 设置文件权限为当前用户可读写
- **AND** 其他用户仅可读（如系统支持）
- **AND** 不设置 Everyone 完全控制权限

#### Scenario: 敏感信息保护

- **假设** 日志内容包含 JWT Token 或密码
- **WHEN** 应用记录日志
- **THEN** 系统 SHOULD 对敏感字段进行脱敏
- **AND** Token 显示为 `eyJ***...`
- **AND** 密码显示为 `******`
- **AND** 脱敏规则在日志配置中定义
