## ADDED Requirements

### Requirement: Urban 对外在线激活端点

UrbanManagement SHALL 暴露 `POST /api/urban/auth/activate`，作为 MaterialClient.Urban 在线激活的唯一 BFF 入口。请求体 SHALL 包含 `productCode`（int）、`code`（接入码/授权码）、`machineCode`（客户端机器码）。成功响应 SHALL 使用与 BasePlatform 一致的包装格式（`success`、`msg`、`data`），且 `data` SHALL 包含 `jwtToken`、`proId`、`proName`、`accessCode`、`authEndDate`。

#### Scenario: 端点路由与 HTTP 方法

- **WHEN** 客户端向 Urban 发送 `POST /api/urban/auth/activate`
- **THEN** 请求 SHALL 由 Urban 授权激活模块处理（非 BasePlatform 直连）
- **AND** Content-Type SHALL 为 `application/json`

#### Scenario: 成功激活透传 BasePlatform JWT

- **WHEN** 请求参数合法且 BasePlatform `activate-urban` 返回 `success=true` 且 `data.jwtToken` 非空
- **THEN** Urban SHALL 向客户端返回 HTTP 200
- **AND** 响应 `data.jwtToken` SHALL 为 BasePlatform 签发（`iss=BasePlatform`）
- **AND** 响应 `data` SHALL 包含 `proId`、`proName`、`accessCode`、`authEndDate` 字段（与 BasePlatform 一致）

#### Scenario: 禁止客户端直连 BasePlatform 激活

- **WHEN** MaterialClient.Urban 执行 ProductCode 5001 在线激活
- **THEN** 客户端 SHALL 仅调用 Urban `POST /api/urban/auth/activate`
- **AND** Urban 本 change 不提供将客户端重定向到 BasePlatform `activate-urban` 的公开文档或 CORS 直通

### Requirement: UrbanAuthActivateAppService 代理 BasePlatform

系统 SHALL 提供 `UrbanAuthActivateAppService`（或等价 `*AppService`）实现 `ActivateAsync`：校验入参 → 调用 `IBasePlatformAuthHttpClient.ActivateAsync` → 可选更新 `GovProject` → 返回响应 DTO。涉及 `GovProject` 写入的方法 SHALL 使用 `[UnitOfWork]`。

#### Scenario: 调用 BasePlatform activate-urban

- **WHEN** `ActivateAsync` 收到合法请求
- **THEN** SHALL 调用 BasePlatform `POST /api/auth/activate-urban`
- **AND** 请求体 SHALL 包含 `productCode=5001`、`code`、`machineCode`（与客户端请求一致）
- **AND** SHALL 使用已注册的 `IBasePlatformAuthHttpClient` Refit 客户端（与 `GetLicenseFileAsync` 相同 BaseUrl 配置）

#### Scenario: BasePlatform 失败时不更新 GovProject

- **WHEN** BasePlatform 返回 `success=false` 或 HTTP 错误
- **THEN** SHALL NOT 更新任何 `GovProject` 记录
- **AND** SHALL 向客户端返回失败响应，`msg` 来自 BasePlatform 或等效用户可读消息
- **AND** SHALL 记录错误日志（不含完整授权码明文）

#### Scenario: 激活成功后同步 GovProject.MachineCode

- **WHEN** BasePlatform 激活成功且 `data.proId` 可解析为 Guid
- **AND** 本地存在匹配 `GovProject.Id` 的记录
- **THEN** SHALL 将 `GovProject.MachineCode` 更新为请求中的 `machineCode`
- **AND** 若 `data.accessCode` 非空，SHALL 更新 `GovProject.AccessCode`
- **AND** 若 `data.authEndDate` 可解析，SHALL 更新 `GovProject.AuthEndTime`（或等价授权截止日期字段）

#### Scenario: 本地无 GovProject 时仍返回 JWT

- **WHEN** BasePlatform 激活成功但本地不存在匹配 `proId` 的 `GovProject`
- **THEN** SHALL 仍向客户端返回成功响应及 `jwtToken`
- **AND** SHALL 记录 Warning 日志（含 `proId`）
- **AND** SHALL NOT 因本地缺失项目而将 HTTP 成功改为失败

### Requirement: 激活入参校验

Urban 代理层 SHALL 在调用 BasePlatform 之前校验在线激活入参。

#### Scenario: 仅接受 ProductCode 5001

- **WHEN** 请求 `productCode` 不等于 `5001`
- **THEN** SHALL 返回失败响应（HTTP 4xx）
- **AND** 错误消息 SHALL 说明该产品不支持 Urban 在线激活
- **AND** SHALL NOT 调用 BasePlatform

#### Scenario: 必填字段非空

- **WHEN** `code` 或 `machineCode` 为空或仅空白
- **THEN** SHALL 返回失败响应（HTTP 4xx）
- **AND** SHALL NOT 调用 BasePlatform

### Requirement: 匿名客户端激活访问

在线激活端点 SHALL 允许未登录的 MaterialClient.Urban 调用（无 ABP 用户会话）。

#### Scenario: 无 Bearer Token 仍可激活

- **WHEN** 客户端请求 `POST /api/urban/auth/activate` 且不携带用户认证 Token
- **THEN** 在参数合法且 BasePlatform 成功时 SHALL 返回 200 及 JWT
- **AND** SHALL NOT 要求 Urban 后台用户登录
