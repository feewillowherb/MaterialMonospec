## MODIFIED Requirements

### Requirement: Recycle 使用 IMaterialPlatformApi 仅用于登录
Recycle 客户端 SHALL 仅通过 `IMaterialPlatformApi.UserLoginAsync` 建立操作员会话；SHALL NOT 调用 MaterialPlatform 业务数据同步接口（如 `SynchronizationOrderAsync`、运单上传、附件 OSS 同步等）。

#### Scenario: 登录接口可用
- **WHEN** Recycle 用户提交用户名密码登录
- **THEN** SHALL 调用 `IMaterialPlatformApi.UserLoginAsync`
- **AND** 登录成功后 SHALL 建立本地 `UserSession`

#### Scenario: 不注册 MaterialPlatform 同步 BackgroundWorker
- **WHEN** Recycle 应用初始化后台服务
- **THEN** SHALL NOT 注册 `MaterialClient.Backgrounds.PollingBackgroundService`
- **AND** SHALL NOT 注册依赖 MaterialPlatform 同步的 Waybill 上报 Worker

#### Scenario: 业务数据走我方平台接收接口
- **WHEN** Recycle 称重记录需要上报
- **THEN** SHALL 由平台上传服务提交至我方平台接收 API
- **AND** SHALL NOT 经 `IMaterialPlatformApi` 提交
- **AND** SHALL NOT 经 `IRecycleDataApi` 作为产品主路径提交

### Requirement: Recycle Refit 客户端注册边界
`MaterialClientRecycleModule` SHALL 注册：`IBasePlatformApi`、`IMaterialPlatformApi`（登录）、以及我方平台接收客户端（`RecyclePlatform:BaseUrl`）。市平台 `IRecycleDataApi` SHALL NOT 在默认产品配置下作为业务上报客户端启用。

#### Scenario: 授权与登录与平台接收可解析
- **WHEN** Recycle 应用 DI 容器构建完成
- **THEN** `IBasePlatformApi`、`IMaterialPlatformApi` 与平台接收客户端 SHALL 均可解析

#### Scenario: 市平台客户端默认不启用业务上报
- **WHEN** `RecycleSync:Enabled` 为 false 或未配置
- **THEN** SHALL NOT 注册或启动面向市平台的轮询上报后台服务
