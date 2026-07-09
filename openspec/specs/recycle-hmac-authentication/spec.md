# Recycle HMAC Authentication

## Purpose

定义 MaterialClient.Recycle 项目的 HMAC-SHA256 签名认证机制，用于与资源化利用厂管理系统 API 通信时的身份验证。

## Requirements

### Requirement: HMAC-SHA256 签名字符串构造
`RecycleHmacDelegatingHandler` SHALL 按接口文档规范构造签名字符串，格式为 `{HTTP_METHOD}\n{sorted_query_string}\n{accessKey}\n{GMT_date}\n`。

#### Scenario: POST 请求无查询参数
- **WHEN** 发起 POST 请求到 `/dataCenter/resourcePlace/productTransportRecord/v1/addBatch`
- **AND** 请求无查询参数
- **THEN** 签名字符串 SHALL 为 `POST\n\n{accessKey}\n{gmtDateTime}\n`
- **AND** `sorted_query_string` SHALL 为空字符串

#### Scenario: 签名字符串各部分正确拼接
- **WHEN** HTTP 方法为 POST、无查询参数、accessKey 为 "testKey"、GMT 时间为 "Tue, 08 Jul 2026 08:49:20 GMT"
- **THEN** 签名字符串 SHALL 为 `POST\n\ntestKey\nTue, 08 Jul 2026 08:49:20 GMT\n`

### Requirement: HMAC-SHA256 签名计算
`RecycleHmacDelegatingHandler` SHALL 使用 `secretKey` 对签名字符串计算 HMAC-SHA256 哈希，并将结果进行 Base64 编码。

#### Scenario: 签名计算
- **WHEN** 签名字符串为 `POST\n\ntestKey\nTue, 08 Jul 2026 08:49:20 GMT\n`
- **AND** secretKey 为 "testSecret"
- **THEN** SHALL 使用 `HMACSHA256` 算法（密钥为 UTF-8 编码的 secretKey）计算哈希
- **AND** SHALL 将哈希字节使用 `Convert.ToBase64String()` 编码
- **AND** 结果 SHALL 赋值给 `X-AKZTJG-HMAC-SIGNATURE` Header

### Requirement: GMT+8 时间戳生成
`RecycleHmacDelegatingHandler` SHALL 生成 GMT+8 时区的 RFC 1123 格式时间戳，赋值给 `X-AKZTJG-DATE-TIME` Header。

#### Scenario: 时间戳格式
- **WHEN** 构造 HMAC 签名 Header
- **THEN** `X-AKZTJG-DATE-TIME` SHALL 为 RFC 1123 格式
- **AND** 时区 SHALL 为 China Standard Time（GMT+8）
- **AND** 示例值 SHALL 类似 `"Tue, 08 Jul 2026 08:49:20 GMT"`
- **AND** 注：接口文档标注允许最大误差 100 秒

### Requirement: 四个 HMAC Header 注入
`RecycleHmacDelegatingHandler` SHALL 在每个请求中注入以下 4 个自定义 Header。

#### Scenario: Header 完整注入
- **WHEN** 通过 `IRecycleDataApi` 发起 HTTP 请求
- **THEN** 请求 SHALL 包含 Header `X-AKZTJG-HMAC-SIGNATURE`（Base64 签名值）
- **AND** SHALL 包含 Header `X-AKZTJG-HMAC-ALGORITHM`（固定值 `hmac-sha256`）
- **AND** SHALL 包含 Header `X-AKZTJG-HMAC-ACCESS-KEY`（`RecycleSyncOptions.AccessKey` 值）
- **AND** SHALL 包含 Header `X-AKZTJG-DATE-TIME`（GMT+8 RFC 1123 时间戳）

#### Scenario: 签名 Header 每次请求动态计算
- **WHEN** 连续发起 2 个请求
- **THEN** 每个请求的 `X-AKZTJG-HMAC-SIGNATURE` SHALL 不同（因时间戳变化）
- **AND** 每个请求的 `X-AKZTJG-DATE-TIME` SHALL 不同

### Requirement: DelegatingHandler 在 HttpClient 管道中的位置
`RecycleHmacDelegatingHandler` SHALL 通过 Refit `AddRefitClient` 配置添加到 HttpClient 管道中，确保在每个 API 请求发送前执行签名。

#### Scenario: 管道顺序
- **WHEN** `IRecycleDataApi` 发起请求
- **THEN** `RecycleHmacDelegatingHandler` SHALL 在请求发送前拦截
- **AND** SHALL 计算签名并注入 Header 后再发送

### Requirement: 配置缺失时的处理
`RecycleHmacDelegatingHandler` SHALL 在 `RecycleSyncOptions` 的 `AccessKey` 或 `SecretKey` 为 null 或空字符串时记录错误日志并 SHALL NOT 发送请求。

#### Scenario: 缺少 accessKey
- **WHEN** `RecycleSyncOptions.AccessKey` 为 null 或空字符串
- **THEN** SHALL 记录 `LogError` 日志，包含 "Recycle HMAC accessKey not configured" 消息
- **AND** SHALL 抛出 `InvalidOperationException`

#### Scenario: 缺少 secretKey
- **WHEN** `RecycleSyncOptions.SecretKey` 为 null 或空字符串
- **THEN** SHALL 记录 `LogError` 日志，包含 "Recycle HMAC secretKey not configured" 消息
- **AND** SHALL 抛出 `InvalidOperationException`
