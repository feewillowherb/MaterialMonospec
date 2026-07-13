# Recycle Startup Auth Flow

## Purpose

定义 Recycle 独立客户端启动时的三段式流程：授权码激活（ProductCode 5020）→ MaterialPlatform 登录 → 显示 Attended 称重主界面，并由 `RecycleStartupService` 协调，沿用非 JWT 授权模式。

## Requirements

### Requirement: Recycle 三段式启动流程
Recycle 独立客户端 SHALL 在应用启动时执行与 SolidWaste 等价的三段式流程：授权码激活 → MaterialPlatform 登录 → 显示称重主界面。

#### Scenario: 无有效 License 时显示授权窗口
- **WHEN** Recycle 应用启动且 `IsLicenseValidAsync()` 返回 `false`
- **THEN** SHALL 显示授权码输入窗口（非 MessageBox 直退）
- **AND** 用户输入授权码后 SHALL 调用 `VerifyAuthorizationCodeAsync(code, ProductCode.Recycle)`
- **AND** 验证成功后才进入登录或主界面流程

#### Scenario: 无活跃会话时显示登录窗口
- **WHEN** 授权有效且 `HasActiveSessionAsync()` 返回 `false`
- **THEN** SHALL 显示登录窗口
- **AND** 用户登录成功后 SHALL 调用 `IAuthenticationService.LoginAsync`（经 `IMaterialPlatformApi.UserLoginAsync`）

#### Scenario: 授权与登录均有效时直接进入主界面
- **WHEN** Recycle 应用启动且 License 有效且存在活跃会话
- **THEN** SHALL 直接显示 Attended 称重主界面
- **AND** SHALL NOT 显示授权或登录窗口

#### Scenario: 用户取消授权或登录
- **WHEN** 用户在授权窗口或登录窗口关闭窗口且未完成验证/登录
- **THEN** 应用 SHALL 退出
- **AND** SHALL NOT 显示称重主界面

### Requirement: Recycle 授权码固定 ProductCode 5020
Recycle 启动路径下的授权码验证 SHALL 固定使用 `ProductCode.Recycle`（5020），SHALL NOT 提供 Standard/SolidWaste 模式选择。

#### Scenario: 授权验证使用 5020
- **WHEN** Recycle 授权窗口提交授权码
- **THEN** `VerifyAuthorizationCodeAsync` SHALL 以 `ProductCode.Recycle` 调用 `IBasePlatformApi.GetAuthClientLicenseAsync`
- **AND** SHALL NOT 使用 `ProductCode.Standard` 或 `ProductCode.SolidWaste`

#### Scenario: 授权成功后持久化 Recycle 称重模式
- **WHEN** Recycle 授权码验证成功
- **THEN** SHALL 将 `DefaultWeighingMode` 持久化为 `WeighingMode.Recycle`

### Requirement: RecycleStartupService 协调启动
Recycle SHALL 通过 `RecycleStartupService`（或等价服务）协调启动流程，`App.axaml.cs` SHALL 委托该服务而非内联授权逻辑。

#### Scenario: App 委托 StartupService
- **WHEN** `App.OnFrameworkInitializationCompleted` 执行
- **THEN** SHALL 调用 `RecycleStartupService.StartupAsync()`
- **AND** 返回的主窗口 SHALL 为 Attended 称重主界面实例

#### Scenario: 启动失败返回 null
- **WHEN** 用户取消授权或登录
- **THEN** `StartupAsync` SHALL 返回 `null`
- **AND** 应用 SHALL 调用 `desktop.Shutdown()`

### Requirement: Recycle 非 JWT 授权模式
Recycle 授权 SHALL 沿用 SolidWaste（5010）非 JWT 模式：BasePlatform `SendAuthLicense` / `DownloadAuth`，授权 UI 显示 AccessCode + MachineCode。

#### Scenario: 不使用 JWT 激活
- **WHEN** Recycle 客户端执行授权流程
- **THEN** SHALL NOT 调用 Urban 专用 JWT 激活路径（`ActivateUrbanAsync`）
- **AND** SHALL 使用与 5010 相同的 License 下载与本地校验机制
