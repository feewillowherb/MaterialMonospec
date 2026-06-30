# Urban JWT 委托规范

## Purpose

将 UrbanManagement 系统的本地 JWT 签发逻辑委托给 BasePlatform PublicApi，实现统一的授权管理。下线本地 `UrbanLicenseGenerator` 服务，改为调用 BasePlatform 的 `/api/auth/license-file` 端点获取由 BasePlatform 签发的 JWT 令牌。
## Requirements
### Requirement: UrbanManagement JWT 签发委托 BasePlatform

系统 SHALL 下线本地 JWT 签发逻辑（`UrbanLicenseGenerator`），改为调用 BasePlatform PublicApi 的 `/api/auth/license-file` 端点获取由 BasePlatform 签发的 JWT 令牌。

#### Scenario: 删除本地 JWT 签发服务

- **WHEN** 应用启动并扫描依赖注入服务
- **THEN** `UrbanLicenseGenerator` 类 SHALL 标记为 `[Obsolete]` 或完全删除
- **AND** 系统 SHALL 不再注册 `IUrbanLicenseGenerator` 服务（如果有替代实现）
- **AND** 所有引用该服务的代码 SHALL 编译失败或被更新

#### Scenario: 代理 API 调用 BasePlatform

- **WHEN** 客户端调用 `GET /api/urban/auth/license-file?machineCode=xxx&proId=xxx`
- **THEN** `GovProjectLicenseAppService.GenerateAsync` SHALL 调用 BasePlatform PublicApi
- **AND** 该请求 SHALL 包含 `ProductCode = 5001`（Urban 产品代码）
- **AND** 该请求 SHALL 包含 `MachineCode`、`ProId`、`AuthEndDate` 参数
- **AND** 系统 SHALL 将 BasePlatform 返回的 JWT 透传给客户端
- **AND** 响应 Content-Type SHALL 为 `application/octet-stream`
- **AND** 响应文件名 SHALL 为 `license.urban`

#### Scenario: BasePlatform HTTP 客户端配置

- **WHEN** 应用启动并配置 HTTP 客户端
- **THEN** 系统 SHALL 注册 `IBasePlatformAuthHttpClient` Refit 接口
- **AND** 该客户端 SHALL 配置 BasePlatform 基础 URL（来自 `appsettings.json`）
- **AND** 该客户端 SHALL 支持调用 `GetLicenseFileAsync` 方法
- **AND** 该客户端 SHALL 支持调用 `ActivateAsync` 方法（`POST /api/auth/activate-urban`）
- **AND** 超时时间 SHALL 设置为 30 秒

### Requirement: SignalR Hub 推送 BasePlatform JWT

系统 SHALL 在 `DeviceStatusHub` 中推送 JWT 令牌时，确保 JWT 来自 BasePlatform 签发，而非 UrbanManagement 本地签发。

#### Scenario: Hub 方法推送 JWT

- **WHEN** `DeviceStatusHub.UpdateClientLicense` 被调用
- **THEN** 系统 SHALL 从 BasePlatform 获取 JWT 令牌
- **AND** 系统 SHALL 构建 `ClientLicenseUpdateDto` 对象
- **AND** `ClientLicenseUpdateDto.JwtToken` 字段 SHALL 包含 BasePlatform 签发的 JWT
- **AND** 系统 SHALL 通过 SignalR 推送该 DTO 到客户端

#### Scenario: 客户端接收 BasePlatform JWT

- **WHEN** MaterialClient.Urban 收到 SignalR `UpdateClientLicense` 消息
- **THEN** 客户端 SHALL 使用收到的 JWT 更新本地 `LicenseInfo.LatestJwtToken`
- **AND** 客户端 SHALL 验证 JWT 签名（使用 BasePlatform 公钥）
- **AND** 验证通过后，客户端 SHALL 提取 claims 并更新 UI

#### Scenario: Hub 推送失败处理

- **WHEN** 调用 BasePlatform `/api/auth/license-file` 失败
- **THEN** 系统 SHALL 记录错误日志（包含 ProId 和异常信息）
- **AND** 系统 SHALL 向客户端返回错误响应（不推送 JWT）
- **AND** 错误消息 SHALL 不包含敏感信息（如私钥、完整异常堆栈）

### Requirement: JWT 防篡改服务转发 BasePlatform JWT

系统 SHALL 修改 `JwtAntiTamperService.VerifyAndCompareAsync` 方法，使其在验签通过后不再使用 `UrbanLicenseGenerator` 重新签发 JWT，而是直接返回 BasePlatform 提供的 JWT。

#### Scenario: 验签通过后返回 BasePlatform JWT

- **WHEN** `JwtAntiTamperService.VerifyAndCompareAsync` 验证客户端提交的 JWT
- **THEN** 系统 SHALL 使用 BasePlatform 公钥验证 JWT 签名
- **AND** 如果验证通过，系统 SHALL 查询 `GovProject` 确认项目存在
- **AND** 系统 SHALL 从 BasePlatform 重新获取最新 JWT（调用 `/api/auth/license-file`）
- **AND** 系统 SHALL 返回 `JwtAntiTamperResult.Pass` 并附带 BasePlatform JWT
- **AND** 系统 SHALL 不再调用 `UrbanLicenseGenerator.GenerateLicenseToken`

#### Scenario: 验签失败返回错误

- **WHEN** JWT 签名验证失败或已过期
- **THEN** 系统 SHALL 返回 `JwtAntiTamperResult.Fail`
- **AND** 错误消息 SHALL 说明失败原因（如"令牌已过期"、"签名验证失败"）
- **AND** 系统 SHALL 记录警告日志（包含 ProId）

#### Scenario: BasePlatform 调用失败回退

- **WHEN** 调用 BasePlatform `/api/auth/license-file` 失败
- **THEN** 系统 SHALL 记录错误日志
- **AND** 系统 SHALL 返回 `JwtAntiTamperResult.Fail` 并附带错误消息
- **AND** 错误消息 SHALL 说明"无法获取授权令牌，请稍后重试"

### Requirement: 移除 JWT 私钥配置

系统 SHALL 从 `appsettings.json` 中移除 `Jwt:PrivateKey` 配置项，因为不再需要本地签发 JWT。

#### Scenario: 配置文件移除私钥

- **WHEN** 管理员更新 `appsettings.json`
- **THEN** `Jwt:PrivateKey` 配置项 SHALL 被删除或注释掉
- **AND** `Jwt:PublicKey` 配置项 SHALL 保留（用于验证 BasePlatform JWT）
- **AND** 应用启动时 SHALL 不再读取 `Jwt:PrivateKey`

#### Scenario: 应用启动不验证私钥配置

- **WHEN** 应用启动并加载配置
- **THEN** 系统 SHALL 不再抛出"JWT 私钥未配置"异常
- **AND** 系统 SHALL 仅验证 `Jwt:PublicKey` 存在（用于验签）
- **AND** 如果公钥缺失，系统 SHALL 抛出"JWT 公钥未配置"异常

### Requirement: Feature Flag 灰度控制

系统 SHALL 提供 `UseBasePlatformJwtIssuer` 特性标志，用于控制是否启用 BasePlatform JWT 委托逻辑。

#### Scenario: Feature Flag 启用时委托 BasePlatform

- **WHEN** `UseBasePlatformJwtIssuer = true`
- **THEN** `GovProjectLicenseAppService` SHALL 调用 BasePlatform 获取 JWT
- **AND** `JwtAntiTamperService` SHALL 返回 BasePlatform JWT
- **AND** SignalR Hub SHALL 推送 BasePlatform JWT

#### Scenario: Feature Flag 禁用时回退本地签发

- **WHEN** `UseBasePlatformJwtIssuer = false`
- **THEN** `GovProjectLicenseAppService` SHALL 回退到使用 `UrbanLicenseGenerator`
- **AND** `JwtAntiTamperService` SHALL 使用本地重新签发的 JWT
- **AND** 这允许灰度期间快速回滚（仅在验证完成前使用）

#### Scenario: Feature Flag 默认值

- **WHEN** 系统首次启动或配置缺失
- **THEN** `UseBasePlatformJwtIssuer` SHALL 默认为 `true`（新部署默认启用）
- **AND** 旧版本升级时可通过配置手动设置为 `false` 进行回滚

#### Scenario: Feature Flag 配置位置

- **WHEN** 管理员配置特性标志
- **THEN** `UseBasePlatformJwtIssuer` SHALL 位于 `appsettings.json` 的 `UrbanAuth` 节点下
- **AND** 类型 SHALL 为布尔值（`true`/`false`）
- **AND** 示例配置：`"UrbanAuth": { "UseBasePlatformJwtIssuer": true }`

### Requirement: BasePlatform JWT 签发 API 规范

系统 SHALL 要求 BasePlatform 提供 `/api/auth/license-file` 端点，用于签发 Urban 产品的 JWT 令牌。

#### Scenario: BasePlatform API 请求参数

- **WHEN** UrbanManagement 调用 BasePlatform `/api/auth/license-file`
- **THEN** 请求 SHALL 包含 `ProductCode = 5001`（Urban 产品代码）
- **AND** 请求 SHALL 包含 `MachineCode`（客户端机器码）
- **AND** 请求 SHALL 包含 `ProId`（项目 ID）
- **AND** 请求 SHALL 包含 `AuthEndDate`（授权过期时间）

#### Scenario: BasePlatform API 响应格式

- **WHEN** BasePlatform 成功处理 JWT 签发请求
- **THEN** 响应 SHALL 包含 `JwtToken` 字段（字符串，Base64 编码的 JWT）
- **AND** JWT SHALL 使用 RS256 算法签名
- **AND** JWT SHALL 包含以下 claims：
  - `proId`：项目 ID
  - `proName`：项目名称
  - `buildLicenseNo`：接入码（来自 `GovProject.AccessCode`）
  - `fdBuildLicenseNo`：凡东对接码（来自 `GovProject.FdBuildLicenseNo`）
  - `exp`：过期时间戳
  - `iss`：签发者 = "BasePlatform"
  - `aud`：受众 = "MaterialClient.Urban"

#### Scenario: BasePlatform API 错误处理

- **WHEN** BasePlatform 返回错误响应
- **THEN** 系统 SHALL 接收 HTTP 错误状态码（4xx/5xx）
- **AND** 系统 SHALL 解析错误消息（来自响应 body）
- **AND** 系统 SHALL 将错误传递给客户端（不暴露内部细节）

### Requirement: 向后兼容与回滚机制

系统 SHALL 提供向后兼容机制，确保 JWT 委托迁移过程中业务连续性。

#### Scenario: 旧代码兼容处理

- **WHEN** 旧代码尝试使用 `IUrbanLicenseGenerator` 服务
- **THEN** 系统 SHALL 提供替代实现（调用 BasePlatform）
- **AND** 该实现 SHALL 标记为 `[Obsolete]` 警告迁移到新 API
- **AND** 编译时 SHALL 生成警告但不阻止构建（灰度期）

#### Scenario: 回滚到本地签发

- **WHEN** 系统设置 `UseBasePlatformJwtIssuer = false`
- **THEN** 应用 SHALL 回退到使用 `UrbanLicenseGenerator` 本地签发
- **AND** 系统 SHALL 从配置读取 `Jwt:PrivateKey`（如果存在）
- **AND** 如果私钥缺失，系统 SHALL 抛出"回滚失败：私钥未配置"异常

#### Scenario: 灰度期双写模式

- **WHEN** 系统处于 JWT 委托灰度期
- **THEN** 成功获取 BasePlatform JWT 后，系统 SHALL 可选地缓存该 JWT
- **AND** 如果 BasePlatform 调用失败，系统 SHALL 回退到本地签发（如果私钥可用）
- **AND** 系统 SHALL 记录回滚事件到日志（用于监控）

### Requirement: 安全性与密钥管理

系统 SHALL 确保 JWT 委托过程中的安全性，防止密钥泄露和未授权访问。

#### Scenario: BasePlatform 公钥验证

- **WHEN** 系统验证 BasePlatform 签发的 JWT
- **THEN** 系统 SHALL 使用配置的 `Jwt:PublicKey` 进行 RS256 验证
- **AND** 系统 SHALL 验证 `iss` claim = "BasePlatform"
- **AND** 系统 SHALL 验证 `aud` claim = "MaterialClient.Urban"
- **AND** 系统 SHALL 验证 `exp` claim 未过期

#### Scenario: HTTP 客户端通信安全

- **WHEN** UrbanManagement 调用 BasePlatform API
- **THEN** 请求 SHALL 使用 HTTPS 协议（生产环境）
- **AND** 系统 SHALL 验证服务器 SSL 证书（防止中间人攻击）
- **AND** 系统 SHALL 设置合理的超时时间（30 秒）

#### Scenario: 敏感信息不记录日志

- **WHEN** 系统记录 JWT 相关日志
- **THEN** 日志 SHALL 不包含完整的 JWT 令牌内容
- **AND** 日志 SHALL 不包含私钥或公钥的 PEM 内容
- **AND** 日志 MAY 包含 JWT 的前 10 个字符（用于调试）

### Requirement: BasePlatform 在线激活 HTTP 客户端

系统 SHALL 扩展 `IBasePlatformAuthHttpClient`，除 `GetLicenseFileAsync` 外支持 `ActivateAsync` 方法，用于调用 BasePlatform `POST /api/auth/activate-urban` 完成 ProductCode 5001 在线激活。

#### Scenario: Refit 激活方法定义

- **WHEN** 应用启动并注册 `IBasePlatformAuthHttpClient`
- **THEN** 接口 SHALL 包含 `[Post("/api/auth/activate-urban")]` 方法 `ActivateAsync`
- **AND** 方法 SHALL 接受请求 DTO（含 `ProductCode`、`Code`、`MachineCode`）
- **AND** 方法 SHALL 返回 `BasePlatformApiResponse<ActivateUrbanResponseData>`（或等价命名 record/class）

#### Scenario: 激活响应字段映射

- **WHEN** BasePlatform `activate-urban` 返回成功 JSON
- **THEN** Refit 反序列化 SHALL 映射 `data.jwtToken`、`data.proId`、`data.proName`、`data.accessCode`、`data.authEndDate`
- **AND** `success` 与 `msg` 字段 SHALL 与 BasePlatform 包装格式一致

#### Scenario: 与 license-file 共用客户端配置

- **WHEN** `IBasePlatformAuthHttpClient` 调用 `ActivateAsync`
- **THEN** SHALL 使用与 `GetLicenseFileAsync` 相同的 BasePlatform BaseUrl 与超时配置
- **AND** SHALL 使用 `Content-Type: application/json`

