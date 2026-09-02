## MODIFIED Requirements

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（IStaticLicenseChecker）。检查 SHALL 优先使用 `LicenseInfo.LatestJwtToken`，其次回退到 `license.urban` 文件。检查成功后 SHALL 将授权数据（ProId、ProName、BuildLicenseNo、AuthEndTime）写入 `LicenseInfo` 实体。检查失败时 SHALL 将 startup authorization 标记为无效并供 App 层展示未授权提示；所有构建配置 MUST 阻塞进入主界面。

#### Scenario: 启动授权检查
- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 `IStaticLicenseChecker`（`CheckLicenseFromTokenAsync` 或 `CheckLicenseAsync`）
- **AND** SHALL 读取 `SystemSettings.LicenseFilePath`（默认 `license.urban`）作为文件回退路径
- **AND** SHALL 记录检查结果到日志

#### Scenario: 授权数据写入 LicenseInfo
- **WHEN** startup JWT 校验返回成功且 `LicenseCheckResult.ProId` 有效
- **THEN** SHALL 读取 `LicenseCheckResult` 中的 ProId、ProName、BuildLicenseNo、AuthEndTime
- **AND** SHALL 通过 IRepository&lt;LicenseInfo, Guid&gt; 写入或更新 `LicenseInfo` 记录
- **AND** MUST NOT 写入 `FdBuildLicenseNo`
- **AND** SHALL 在 UnitOfWork 中执行写入操作

#### Scenario: 授权检查失败不写入且阻塞启动
- **WHEN** startup JWT 校验返回失败
- **THEN** SHALL NOT 修改 `LicenseInfo` 记录
