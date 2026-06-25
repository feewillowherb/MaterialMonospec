## MODIFIED Requirements

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（`IStaticLicenseChecker`）。检查 SHALL 优先使用 `LicenseInfo.LatestJwtToken`，其次回退到 `license.urban` 文件。验签 SHALL 要求 `iss=BasePlatform`、`accessCode` claim 及 `machineCode` 与本机一致。检查成功后 SHALL 将授权数据（`ProId`、`ProName`、**`AccessCode`**、`AuthEndTime`）写入 `LicenseInfo` 实体；从文件 bootstrap 成功时 SHALL 回写 `LatestJwtToken`。检查失败时 SHALL 将 startup authorization 标记为无效并供 App 层展示未授权提示；所有构建配置 MUST 阻塞进入主界面。MUST NOT 写入 `FdBuildLicenseNo` 或 `AuthToken`。

#### Scenario: 启动授权检查

- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 `IStaticLicenseChecker`（`CheckLicenseFromTokenAsync` 或 `CheckLicenseAsync`）
- **AND** SHALL 读取 `SystemSettings.LicenseFilePath`（默认 `license.urban`）作为文件回退路径
- **AND** SHALL 使用 BasePlatform 公钥与 `iss=BasePlatform` 验签
- **AND** SHALL 记录检查结果到日志

#### Scenario: 授权数据写入 LicenseInfo

- **WHEN** startup JWT 校验返回成功且 `LicenseCheckResult.ProId` 有效
- **THEN** SHALL 读取 `LicenseCheckResult` 中的 `ProId`、`ProName`、**`AccessCode`**、`AuthEndTime`
- **AND** SHALL 通过 `IRepository<LicenseInfo, Guid>` 写入或更新 `LicenseInfo` 记录
- **AND** SHALL 在 UnitOfWork 中执行写入操作
- **AND** MUST NOT 写入 `FdBuildLicenseNo` 或 `AuthToken`

#### Scenario: Bootstrap 回写 LatestJwtToken

- **WHEN** 启动从 `license.urban` 文件验签成功且此前 `LatestJwtToken` 为空
- **THEN** SHALL 将文件 JWT 全文写入 `LicenseInfo.LatestJwtToken`

#### Scenario: 授权检查失败不写入且阻塞启动

- **WHEN** startup JWT 校验返回失败（含 issuer 非 BasePlatform、machineCode 不匹配、缺少 accessCode）
- **THEN** SHALL NOT 修改 `LicenseInfo` 记录
- **AND** SHALL 记录警告日志
- **AND** SHALL 将 startup authorization 标记为无效
- **AND** 应用 MUST NOT 进入称重主界面

#### Scenario: Debug 模式状态显示

- **WHEN** 应用在 Debug 模式下运行且 startup authorization 成功
- **THEN** SHALL 在设备状态栏显示授权状态文本
- **AND** SHALL 使用绿色（成功）指示器
