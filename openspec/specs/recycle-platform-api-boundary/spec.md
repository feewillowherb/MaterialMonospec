# Recycle Platform API Boundary

## Purpose

定义 Recycle 独立客户端对 BasePlatform / MaterialPlatform / Recycle 外部数据接口的 Refit 客户端边界：授权走 BasePlatform，登录仅用 MaterialPlatform，业务数据上报走 §2.2 `IRecycleDataApi`。
## Requirements
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

### Requirement: 称重数据无条件上传

客户端 SHALL NOT 因数据不全或不合理而跳过回收称重记录的上传。服务端接收 SHALL NOT 以数据内容为由拒绝称重事实，只保留存储层面的限制（来源键、字段长度、小数精度）。车牌为空或毛重为负 SHALL NOT 影响来源键幂等与照片独立上传。

#### Scenario: 无车牌记录完成周期

- **WHEN** 一条没有车牌的回收称重记录完成周期
- **THEN** 客户端把它提交到 `/api/transports/receive`，请求中 `PlateNumber` 为空
- **AND** 服务端返回成功，台账中出现这条运输单

#### Scenario: 负毛重记录完成周期

- **WHEN** 一条毛重为负的回收称重记录完成周期
- **THEN** 服务端返回成功，台账按原值保存毛重

#### Scenario: 有车牌记录不受影响

- **WHEN** 一条有车牌的回收称重记录完成周期
- **THEN** 提交与服务端接收行为与本变更前一致

#### Scenario: 空车牌记录重传

- **WHEN** 客户端用同一来源键重传一条车牌为空的未同步记录
- **THEN** 服务端按幂等规则返回已有运输单，不报内容冲突

#### Scenario: 超出存储精度

- **WHEN** 提交的毛重小数位数超出存储精度
- **THEN** 服务端以 400 拒绝

### Requirement: 永久拒绝标记为同步失败

客户端收到服务端 400 拒绝时 SHALL 把该记录的同步状态改为失败并停止重试。认证失败、网络错误和服务端 5xx SHALL 保持待上传并在后续轮询中重试。已同步的记录 SHALL NOT 被改为失败。

#### Scenario: 服务端拒绝记录

- **WHEN** 服务端以 400 拒绝一条待上传记录
- **THEN** 该记录同步状态为失败
- **AND** 后续轮询不再提交这条记录
- **AND** 客户端称重列表显示该记录为失败

#### Scenario: 服务端暂时不可用

- **WHEN** 提交时网络中断、超时或服务端返回 5xx
- **THEN** 该记录保持待上传，下一轮轮询再次提交

#### Scenario: 认证过期

- **WHEN** 服务端返回 401
- **THEN** 该记录保持待上传，令牌刷新后再次提交

