## ADDED Requirements

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

## MODIFIED Requirements

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
