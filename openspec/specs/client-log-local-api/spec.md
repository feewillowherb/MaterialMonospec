# Client Log Local API Specification

## Purpose

定义 MaterialClient.Urban 客户端的本地 HTTP API 要求，支持 UrbanManagement 服务端通过 HTTP 请求拉取日志文件。API 仅监听 localhost，提供安全的本地文件访问接口。

## Requirements

### Requirement: 本地 HTTP API 服务

客户端必须启动独立的 Kestrel HTTP 服务器，监听 localhost 端口，提供日志文件下载接口。

#### Scenario: 启动本地 API 服务

- **假设** `appsettings.json` 中 `LocalLogApi:Enabled` 为 `true`
- **WHEN** MaterialClient.Urban 应用初始化
- **THEN** 系统 SHALL 在后台启动 Kestrel 服务器
- **AND** 监听地址为 `http://localhost:5900`
- **AND** 注册 `LocalLogController` 控制器
- **AND** 配置路由模板为 `api/[controller]`
- **AND** 启动成功后记录信息日志

#### Scenario: 自定义监听端口

- **假设** `appsettings.json` 中 `LocalLogApi:Port` 设置为 `5901`
- **WHEN** Kestrel 服务器启动
- **THEN** 系统 SHALL 监听 `http://localhost:5901`
- **AND** 配置值有效范围为 1024-65535
- **AND** 端口被占用时 SHALL 抛出 `IOException`

#### Scenario: 禁用本地 API

- **假设** `appsettings.json` 中 `LocalLogApi:Enabled` 为 `false`
- **WHEN** MaterialClient.Urban 应用初始化
- **THEN** 系统 SHALL 跳过 Kestrel 启动
- **AND** 不监听任何端口
- **AND** `LocalLogController` 不可访问

#### Scenario: 仅监听 localhost

- **WHEN** Kestrel 服务器配置
- **THEN** 系统 SHALL 绑定至 `127.0.0.1` 或 `localhost`
- **AND** 不绑定至 `0.0.0.0` 或外部网卡
- **AND** 拒绝非 localhost 来源的请求

### Requirement: 日志文件下载接口

API 必须提供 GET 端点下载指定路径的日志文件。

#### Scenario: 下载单个日志文件

- **假设** 文件 `Logs/2025/06/22/MaterialClient-20250622.log` 存在
- **WHEN** 请求 `GET /api/local-log/download?filePath=2025/06/22/&fileName=MaterialClient-20250622.log`
- **THEN** 系统 SHALL 验证路径参数安全性
- **AND** 返回文件流（`application/octet-stream` 或 `text/plain`）
- **AND** 设置 `Content-Disposition: attachment; filename="MaterialClient-20250622.log"`
- **AND** HTTP 状态码为 200

#### Scenario: 文件不存在

- **假设** 请求的文件不存在
- **WHEN** 请求 `GET /api/local-log/download`
- **THEN** 系统 SHALL 返回 HTTP 404 Not Found
- **AND** 响应体包含错误信息 `{"error": "日志文件不存在", "path": "..."}`
- **AND** 记录警告日志

#### Scenario: 路径遍历攻击防护

- **假设** 请求包含 `..` 或绝对路径
- **WHEN** 请求 `GET /api/local-log/download?filePath=../../Windows/&fileName=not-a-log.txt`
- **THEN** 系统 SHALL 验证路径在 `Logs/` 目录内
- **AND** 拒绝访问目录遍历请求
- **AND** 返回 HTTP 400 Bad Request
- **AND** 记录安全警告日志

#### Scenario: 支持断点续传

- **假设** 文件大小为 50 MB
- **WHEN** 请求包含 `Range: bytes=1048576-`
- **THEN** 系统 SHALL 返回 HTTP 206 Partial Content
- **AND** 设置 `Content-Length` 为剩余字节数
- **AND** 设置 `Content-Range: bytes 1048576-52428800/52428801`
- **AND** 返回从指定偏移量开始的文件流

#### Scenario: 参数验证

- **WHEN** 请求缺少 `filePath` 或 `fileName` 参数
- **THEN** 系统 SHALL 返回 HTTP 400 Bad Request
- **AND** 响应体包含参数错误提示
- **AND** 记录调试日志

### Requirement: 日志文件列表接口

API 必须提供 GET 端点查询日志文件列表（调试用途）。

#### Scenario: 列出指定日期的日志

- **假设** 日志目录 `Logs/2025/06/22/` 包含 3 个文件
- **WHEN** 请求 `GET /api/local-log/list?dateFolder=2025/06/22/`
- **THEN** 系统 SHALL 扫描指定目录
- **AND** 返回 JSON 数组：`[{"fileName": "...", "filePath": "...", "fileSize": 5242880, "lastModified": "2025-06-22T23:59:59+08:00"}]`
- **AND** HTTP 状态码为 200

#### Scenario: 列出所有日志

- **WHEN** 请求 `GET /api/local-log/list`（不带参数）
- **THEN** 系统 SHALL 递归扫描 `Logs/` 目录
- **AND** 返回所有 `.log` 文件
- **AND** 按文件修改时间降序排列
- **AND** 包含完整相对路径和文件大小

#### Scenario: 目录不存在

- **假设** 请求的日期目录不存在
- **WHEN** 请求 `GET /api/local-log/list?dateFolder=2025/13/01/`
- **THEN** 系统 SHALL 返回空数组 `[]`
- **AND** HTTP 状态码为 200
- **AND** 不抛出异常

### Requirement: API 错误处理和日志

API 必须实现完善的错误处理和日志记录。

#### Scenario: 内部服务器错误

- **假设** 文件读取过程中发生未预期异常
- **WHEN** 处理下载请求
- **THEN** 系统 SHALL 返回 HTTP 500 Internal Server Error
- **AND** 响应体包含错误信息 `{"error": "下载失败", "message": "..."}`
- **AND** 记录错误日志（包含异常堆栈）

#### Scenario: 请求日志记录

- **WHEN** API 接收任何请求
- **THEN** 系统 SHALL 记录访问日志
- **AND** 包含请求路径、查询参数、来源 IP
- **AND** 响应成功时记录信息级别日志
- **AND** 响应失败时记录警告或错误级别日志

### Requirement: API 性能和并发

API 必须支持并发请求和合理的超时设置。

#### Scenario: 并发下载支持

- **假设** 服务端同时发起 3 个下载请求
- **WHEN** 处理并发请求
- **THEN** 系统 SHALL 支持至少 5 个并发连接
- **AND** 每个连接独立处理文件流
- **AND** 不阻塞其他请求

#### Scenario: 超时设置

- **WHEN** Kestrel 服务器配置
- **THEN** 系统 SHALL 设置请求超时为 5 分钟
- **AND** 大文件传输超时 SHALL 记录警告日志
- **AND** 超时后 SHALL 关闭连接
- **AND** 不释放文件句柄（确保资源清理）

### Requirement: API 安全性

API 必须限制仅本机访问，防止外部未授权访问。

#### Scenario: 拒绝非 localhost 请求

- **假设** 请求来自 `192.168.1.100:5900`
- **WHEN** 请求到达 Kestrel
- **THEN** 系统 SHALL 检查请求来源
- **AND** 非 localhost 来源 SHALL 返回 HTTP 403 Forbidden
- **AND** 记录安全警告日志

#### Scenario: CORS 配置

- **WHEN** Kestrel 配置 CORS
- **THEN** 系统 SHALL 不启用 CORS（仅 localhost）
- **AND** 跨域请求 SHALL 被拒绝
- **AND** 预检请求 SHALL 返回 403

### Requirement: API 可配置性

API 行为必须可通过配置文件调整。

#### Scenario: 配置服务启动

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 识别 `LocalLogApi` 配置节
- **AND** 包含 `Enabled` 布尔值（默认 true）
- **AND** 包含 `Port` 整数（默认 5900）
- **AND** 配置无效时 SHALL 使用默认值

#### Scenario: 配置端口范围验证

- **WHEN** `LocalLogApi:Port` 设置为 `80`（需要管理员权限）
- **THEN** 系统 SHALL 检测端口权限
- **AND** 无权限时 SHALL 回退到默认端口 5900
- **AND** 记录配置回退日志
