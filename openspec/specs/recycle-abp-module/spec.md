# MaterialClient Recycle ABP Module

## Purpose

定义 MaterialClient.Recycle 项目的 ABP 模块结构，实现独立的 Recycle 称重客户端，复用 MaterialClient.Common 和 MaterialClient.UI 共享层，提供 Recycle 数据同步服务和授权管理。

## Requirements

### Requirement: MaterialClientRecycleModule AbpModule 定义
系统 SHALL 定义 `MaterialClientRecycleModule` 类继承 `AbpModule`，依赖 `MaterialClientCommonModule`、`MaterialClientUiModule`、`AbpAutofacModule`、`AbpBackgroundWorkersModule`。MUST NOT 依赖 `MaterialClientModule`（主应用模块）或 `MaterialClientUrbanModule`。

#### Scenario: 模块依赖链
- **WHEN** ABP 应用以 `MaterialClientRecycleModule` 初始化
- **THEN** 模块 SHALL 依赖 `MaterialClientCommonModule`（提供 EF Core、DbContext、实体、枚举）
- **AND** SHALL 依赖 `MaterialClientUiModule`（提供 Avalonia UI 共享层）
- **AND** SHALL 依赖 `AbpAutofacModule`（提供 Autofac DI 容器）
- **AND** SHALL 依赖 `AbpBackgroundWorkersModule`（提供后台轮询服务支持）
- **AND** MUST NOT 依赖 `MaterialClientModule` 或 `MaterialClientUrbanModule`

### Requirement: Recycle Refit 客户端注册
`MaterialClientRecycleModule` SHALL 在 `ConfigureServices` 中注册 `IRecycleDataApi` Refit 客户端，BaseAddress 绑定到 `RecycleSync:ApiUrl`，Timeout 绑定到 `RecycleSync:TimeoutSeconds`，并附加 `RecycleHmacDelegatingHandler` 到 HttpClient 管道。

#### Scenario: Refit 客户端正确配置
- **WHEN** `ConfigureServices` 执行
- **THEN** SHALL 注册 `RefitClient<IRecycleDataApi>`
- **AND** HttpClient BaseAddress SHALL 为配置 `RecycleSync:ApiUrl` 的值
- **AND** HttpClient Timeout SHALL 为 `RecycleSync:TimeoutSeconds` 秒
- **AND** SHALL 将 `RecycleHmacDelegatingHandler` 添加到 `HttpMessageHandler` 管道

### Requirement: RecycleSyncOptions 配置绑定
`MaterialClientRecycleModule` SHALL 在 `ConfigureServices` 中将 `RecycleSync` 配置段绑定到 `RecycleSyncOptions` 类。

#### Scenario: 配置段正确绑定
- **WHEN** `appsettings.json` 包含 `RecycleSync` 配置段（Enabled、ApiUrl、AccessKey、SecretKey、PointNumber、ProductName、PollIntervalSeconds、MaxFailCount、TimeoutSeconds）
- **THEN** `IOptions<RecycleSyncOptions>` SHALL 包含所有配置值
- **AND** 默认值 SHALL 为：PollIntervalSeconds=5、MaxFailCount=9、TimeoutSeconds=30

### Requirement: Recycle 默认 WeighingMode 设置
`MaterialClientRecycleModule` SHALL 在应用初始化时确保 `SystemSettings.DefaultWeighingMode` 为 `WeighingMode.Recycle`（值 301）。

#### Scenario: 首次启动设置默认模式
- **WHEN** Recycle 应用首次启动且 `SystemSettings.DefaultWeighingMode` 不为 `WeighingMode.Recycle`
- **THEN** SHALL 将 `DefaultWeighingMode` 设置为 `WeighingMode.Recycle`
- **AND** SHALL 持久化设置到 SQLite

#### Scenario: 已是 Recycle 模式不做修改
- **WHEN** Recycle 应用启动且 `SystemSettings.DefaultWeighingMode` 已为 `WeighingMode.Recycle`
- **THEN** SHALL NOT 修改设置

### Requirement: Recycle 后台轮询服务注册
`MaterialClientRecycleModule` SHALL 在应用初始化时（授权/登录完成、主界面就绪后）注册 `RecyclePollingBackgroundService` 作为 ABP 后台 Worker。

#### Scenario: 轮询服务注册
- **WHEN** `RecycleSync:Enabled` 为 `true` 且应用已完成启动流程
- **THEN** SHALL 注册 `RecyclePollingBackgroundService`
- **AND** MUST NOT 注册 `MaterialClient.Backgrounds.PollingBackgroundService`（主程序轮询）

#### Scenario: 轮询服务未启用时不注册
- **WHEN** `RecycleSync:Enabled` 为 `false`
- **THEN** SHALL NOT 注册 `RecyclePollingBackgroundService`

### Requirement: Recycle 数据库迁移
`MaterialClientRecycleModule` SHALL 在应用初始化时执行 EF Core 数据库迁移，确保 `WeighingRecord`、`AttachmentFile` 等共享实体的表结构存在。

#### Scenario: 数据库迁移执行
- **WHEN** `OnApplicationInitializationAsync` 执行
- **THEN** SHALL 调用 `Database.MigrateAsync()` 执行迁移
- **AND** 迁移 SHALL 使用 `MaterialClient.Common` 的 DbContext

### Requirement: Recycle 应用启动入口
Recycle 应用 SHALL 拥有独立的 `Program.cs` 和 `App.axaml.cs`，遵循 Urban 模块的启动模式。

#### Scenario: 单实例 Mutex
- **WHEN** 用户启动 Recycle 应用
- **THEN** SHALL 使用命名 Mutex（`MaterialClient_Recycle_SingleInstance_Mutex`）确保单实例运行
- **AND** 若已有实例运行 SHALL 静默退出

#### Scenario: ABP 初始化与主窗口
- **WHEN** Recycle 应用启动完成 ABP 初始化且 `RecycleStartupService` 返回主窗口
- **THEN** SHALL 显示 Attended 称重主界面（SolidWaste 等价 UI）
- **AND** SHALL 通过 ABP 容器初始化称重管线服务
- **AND** SHALL NOT 显示占位 `RecycleMainWindow` 作为最终主界面

#### Scenario: 授权或登录未完成时退出
- **WHEN** Recycle 应用启动且用户未完成授权码激活或 MaterialPlatform 登录
- **THEN** SHALL 在授权/登录窗口关闭后退出应用
- **AND** SHALL NOT 仅显示 MessageBox「软件未授权」作为唯一交互（授权流程 MUST 提供授权码输入能力）
