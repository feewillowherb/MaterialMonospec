## ADDED Requirements

### Requirement: Recycle 使用 IBasePlatformApi 进行授权
Recycle 客户端 SHALL 通过 `IBasePlatformApi` 完成授权码验证与 License 获取；该 API SHALL 在 `MaterialClientRecycleModule` 中通过 `AddMaterialClientRefitClients` 注册。

#### Scenario: BasePlatform 客户端已注册
- **WHEN** `MaterialClientRecycleModule.ConfigureServices` 执行
- **THEN** `IBasePlatformApi` SHALL 可通过 DI 解析
- **AND** Recycle 授权流程 SHALL 可调用 `GetAuthClientLicenseAsync`

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

#### Scenario: 业务数据走 §2.2 外部接口
- **WHEN** Recycle 称重记录需要上报
- **THEN** SHALL 由 `RecycleDataSyncService` 经 `IRecycleDataApi` 提交至 `/dataCenter/resourcePlace/productTransportRecord/v1/addBatch`
- **AND** SHALL NOT 经 `IMaterialPlatformApi` 提交

### Requirement: Recycle Refit 客户端注册边界
`MaterialClientRecycleModule` SHALL 注册三类 HTTP 客户端：`IBasePlatformApi`、`IMaterialPlatformApi`（Common 共享注册）、`IRecycleDataApi`（Recycle 专属 HMAC）。

#### Scenario: 三类客户端均可解析
- **WHEN** Recycle 应用 DI 容器构建完成
- **THEN** `IBasePlatformApi`、`IMaterialPlatformApi`、`IRecycleDataApi` SHALL 均可解析
- **AND** `IRecycleDataApi` SHALL 附加 `RecycleHmacDelegatingHandler`
