## MODIFIED Requirements

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

### Requirement: Recycle 后台轮询服务注册
`MaterialClientRecycleModule` SHALL 在应用初始化时（授权/登录完成、主界面就绪后）注册 `RecyclePollingBackgroundService` 作为 ABP 后台 Worker。

#### Scenario: 轮询服务注册
- **WHEN** `RecycleSync:Enabled` 为 `true` 且应用已完成启动流程
- **THEN** SHALL 注册 `RecyclePollingBackgroundService`
- **AND** MUST NOT 注册 `MaterialClient.Backgrounds.PollingBackgroundService`（主程序轮询）

#### Scenario: 轮询服务未启用时不注册
- **WHEN** `RecycleSync:Enabled` 为 `false`
- **THEN** SHALL NOT 注册 `RecyclePollingBackgroundService`
