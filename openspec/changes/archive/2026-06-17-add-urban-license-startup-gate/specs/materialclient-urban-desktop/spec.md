## MODIFIED Requirements

### Requirement: Urban 应用启动进入唯一主界面

MaterialClient.Urban 应用启动时，在 startup authorization 有效时 MUST 直接显示称重主界面（UrbanAttendedWeighingWindow）。MUST NOT 显示登录窗口或授权码输入窗口。当 startup authorization 无效时，MUST NOT 显示称重主界面，SHALL 显示未授权提示对话框后退出。启动完成后 SHALL 通过 ABP 容器初始化称重管线服务（仅授权成功路径）。

#### Scenario: 正常启动流程

- **WHEN** 用户启动 MaterialClient.Urban 应用
- **AND** startup JWT authorization 成功且 `ProId` 有效
- **THEN** SHALL 通过 ABP AbpApplicationFactory 初始化应用
- **AND** SHALL 在 Program.cs 中配置 `.UseReactiveUI()` 平台集成
- **AND** SHALL 直接显示称重主界面 UrbanAttendedWeighingWindow（1280×800）
- **AND** SHALL NOT 显示登录窗口
- **AND** SHALL NOT 显示授权码输入窗口
- **AND** SHALL 记录授权检查结果到日志
- **AND** SHALL 通过 ABP 隐式注册解析 ViewModel 和服务

#### Scenario: 未授权时中断启动

- **WHEN** 用户启动 MaterialClient.Urban 应用
- **AND** startup JWT authorization 失败（无有效 `license.urban`、无有效 `LatestJwtToken`、JWT 无效或过期、或无法解析 `ProId`）
- **THEN** SHALL NOT 显示称重主界面 UrbanAttendedWeighingWindow
- **AND** SHALL 显示「软件未授权」提示对话框
- **AND** SHALL 在用户确认后退出应用
- **AND** SHALL NOT 启动称重管线或硬件设备管理器

#### Scenario: 启动失败处理

- **WHEN** ABP 初始化失败
- **THEN** SHALL 记录错误日志
- **AND** SHALL 调用 desktop.Shutdown() 退出应用

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（IStaticLicenseChecker）。检查 SHALL 优先使用 `LicenseInfo.LatestJwtToken`，其次回退到 `license.urban` 文件。检查成功后 SHALL 将授权数据（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo、AuthEndTime）写入 `LicenseInfo` 实体。检查失败时 SHALL 将 startup authorization 标记为无效并供 App 层展示未授权提示；所有构建配置 MUST 阻塞进入主界面。

#### Scenario: 启动授权检查

- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 `IStaticLicenseChecker`（`CheckLicenseFromTokenAsync` 或 `CheckLicenseAsync`）
- **AND** SHALL 读取 `SystemSettings.LicenseFilePath`（默认 `license.urban`）作为文件回退路径
- **AND** SHALL 记录检查结果到日志

#### Scenario: 授权数据写入 LicenseInfo

- **WHEN** startup JWT 校验返回成功且 `LicenseCheckResult.ProId` 有效
- **THEN** SHALL 读取 `LicenseCheckResult` 中的 ProId、ProName、BuildLicenseNo、FdBuildLicenseNo、AuthEndTime
- **AND** SHALL 通过 `IRepository<LicenseInfo, Guid>` 写入或更新 `LicenseInfo` 记录
- **AND** SHALL 在 UnitOfWork 中执行写入操作

#### Scenario: 授权检查失败不写入且阻塞启动

- **WHEN** startup JWT 校验返回失败
- **THEN** SHALL NOT 修改 `LicenseInfo` 记录
- **AND** SHALL 记录警告日志
- **AND** SHALL 将 startup authorization 标记为无效
- **AND** 应用 MUST NOT 进入称重主界面

#### Scenario: Debug 模式状态显示

- **WHEN** 应用在 Debug 模式下运行且 startup authorization 成功
- **THEN** SHALL 在设备状态栏显示授权状态文本
- **AND** SHALL 使用绿色（成功）指示器

## REMOVED Requirements

### Requirement: 静态授权检查 — 后台授权检查（不向 UI 暴露）

**Reason**: 替换为启动门禁；未授权时需向用户显示「软件未授权」对话框。

**Migration**: 使用 MODIFIED「静态授权检查」中的「启动授权检查」与「授权检查失败不写入且阻塞启动」场景。

### Requirement: 静态授权检查 — 授权检查失败继续启动（非阻塞）

**Reason**: 生产环境要求无有效 ProId 时不得进入称重主界面。

**Migration**: 部署有效 `license.urban` 或确保 `LatestJwtToken` 有效后再启动应用。
