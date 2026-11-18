## MODIFIED Requirements

### Requirement: Recycle 三段式启动流程
Recycle 独立客户端 SHALL 在应用启动时执行：**本地授权校验 / 在线激活（5020）→ 显示称重主界面**。SHALL NOT 要求 MaterialPlatform 账号登录。

#### Scenario: 无有效 License 时显示激活窗口
- **WHEN** Recycle 应用启动且本地授权无效
- **THEN** SHALL 显示仅含激活码录入的激活窗口（机器码只读或自动携带）
- **AND** 激活成功后 SHALL 进入称重主界面
- **AND** SHALL NOT 进入 Material 登录步骤

#### Scenario: 授权有效时直接进入主界面
- **WHEN** Recycle 应用启动且本地授权有效
- **THEN** SHALL 直接显示 Recycle 称重主界面
- **AND** SHALL NOT 显示激活或登录窗口

#### Scenario: 用户取消激活
- **WHEN** 用户关闭激活窗口且未完成激活
- **THEN** 应用 SHALL 退出
- **AND** SHALL NOT 显示称重主界面

### Requirement: Recycle 授权码固定 ProductCode 5020
Recycle 启动路径下的在线激活 SHALL 固定使用 `ProductCode.Recycle`（5020），SHALL NOT 提供 Standard/SolidWaste 模式选择。

#### Scenario: 激活使用 5020
- **WHEN** Recycle 激活窗口提交激活码
- **THEN** 请求 SHALL 携带 `ProductCode.Recycle`（5020）与本机机器码
- **AND** SHALL NOT 使用 `ProductCode.Standard` 或 `ProductCode.SolidWaste`

#### Scenario: 激活成功后持久化 Recycle 称重模式
- **WHEN** Recycle 在线激活成功
- **THEN** SHALL 将 `DefaultWeighingMode` 持久化为 `WeighingMode.Recycle`

### Requirement: RecycleStartupService 协调启动
Recycle SHALL 通过启动协调服务（如 `RecycleStartupService`）完成激活门禁与主窗展示，`App.axaml.cs` SHALL 委托该服务而非内联激活逻辑。

#### Scenario: App 委托 StartupService
- **WHEN** `App.OnFrameworkInitializationCompleted` 执行
- **THEN** SHALL 调用启动协调服务
- **AND** 返回的主窗口 SHALL 为 Recycle 称重主界面实例（Urban 同构壳）

#### Scenario: 启动失败返回 null
- **WHEN** 用户取消激活
- **THEN** 启动协调 SHALL 返回失败/空
- **AND** 应用 SHALL 调用 `desktop.Shutdown()`

### Requirement: Recycle 非 JWT 授权模式
Recycle 授权 SHALL 使用与 Urban 同形的**在线 JWT 激活**（PublicApi 激活接口放行 5020）：激活码 + 机器码 → 回写 → JWT。SHALL NOT 以直连 `GetAuthClientLicense` 作为产品主路径。

#### Scenario: 使用在线 JWT 激活
- **WHEN** Recycle 客户端执行授权流程
- **THEN** SHALL 调用 5020 在线激活路径（对齐 `ActivateUrban` 行为）
- **AND** SHALL NOT 以 `GetAuthClientLicenseAsync` 作为产品主路径
