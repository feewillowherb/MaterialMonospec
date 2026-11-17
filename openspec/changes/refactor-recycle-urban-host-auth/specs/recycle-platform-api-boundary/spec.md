## MODIFIED Requirements

### Requirement: Recycle 使用 IBasePlatformApi 进行授权
Recycle 客户端授权主路径 SHALL 为 **5020 在线激活**（经平台代理或 PublicApi 同形接口：激活码 + 机器码 → JWT）。`GetAuthClientLicenseAsync` SHALL NOT 作为产品主路径。

#### Scenario: 在线激活客户端可解析
- **WHEN** `MaterialClientRecycleModule.ConfigureServices` 执行
- **THEN** 在线激活所用 HTTP 客户端 SHALL 可通过 DI 解析
- **AND** Recycle 激活流程 SHALL 可提交 5020 + 机器码

### Requirement: Recycle 使用 IMaterialPlatformApi 仅用于登录
Recycle 客户端 SHALL NOT 要求 MaterialPlatform 账号登录作为启动前置。SHALL NOT 调用 MaterialPlatform 业务数据同步接口（如 `SynchronizationOrderAsync`、运单上传、附件 OSS 同步等）。

#### Scenario: 启动不依赖 Material 登录
- **WHEN** Recycle 用户完成激活或已有有效授权
- **THEN** SHALL 进入称重主界面
- **AND** SHALL NOT 调用 `IMaterialPlatformApi.UserLoginAsync` 作为必经步骤

#### Scenario: 不注册 MaterialPlatform 同步 BackgroundWorker
- **WHEN** Recycle 应用初始化后台服务
- **THEN** SHALL NOT 注册 `MaterialClient.Backgrounds.PollingBackgroundService`
- **AND** SHALL NOT 注册依赖 MaterialPlatform 同步的 Waybill 上报 Worker

#### Scenario: 业务采集上传走我方 Recycle 平台
- **WHEN** Recycle 称重记录需要上报
- **THEN** SHALL 上传至我方 Recycle Web / 平台接收 API
- **AND** SHALL NOT 经 `IMaterialPlatformApi` 提交业务主数据
- **AND** 市平台 HMAC 直连 SHALL NOT 作为产品主路径

### Requirement: Recycle Refit 客户端注册边界
`MaterialClientRecycleModule` SHALL 注册支持在线激活与我方平台上传所需的 HTTP 客户端。市平台 `IRecycleDataApi` HMAC 客户端 MAY 保留但默认 SHALL NOT 作为产品主路径。

#### Scenario: 激活与平台上传客户端可解析
- **WHEN** Recycle 应用 DI 容器构建完成
- **THEN** 在线激活客户端与 Recycle 平台上传客户端 SHALL 可解析
