## MODIFIED Requirements

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（IStaticLicenseChecker），MUST NOT 向 UI 暴露授权状态。检查成功后 SHALL 将授权数据（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo）写入 LicenseInfo 实体持久化到本地数据库。

#### Scenario: 后台授权检查

- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 IStaticLicenseChecker.CheckLicenseAsync
- **AND** SHALL 读取 LicenseFilePath 配置
- **AND** SHALL 记录检查结果到日志
- **AND** MUST NOT 显示授权对话框

#### Scenario: 授权数据写入 LicenseInfo

- **WHEN** IStaticLicenseChecker.CheckLicenseAsync 返回成功
- **THEN** SHALL 读取 LicenseCheckResult 中的 ProId、ProName、BuildLicenseNo、FdBuildLicenseNo
- **AND** SHALL 通过 IRepository&lt;LicenseInfo, Guid&gt; 写入或更新 LicenseInfo 记录
- **AND** SHALL 在 UnitOfWork 中执行写入操作

#### Scenario: 授权检查失败不写入

- **WHEN** IStaticLicenseChecker.CheckLicenseAsync 返回失败
- **THEN** SHALL NOT 修改 LicenseInfo 记录
- **AND** SHALL 记录警告日志
- **AND** 应用 SHALL 继续启动（非阻塞）

#### Scenario: Debug 模式状态显示

- **WHEN** 应用在 Debug 模式下运行
- **THEN** SHALL 在设备状态栏显示授权状态文本
- **AND** SHALL 使用绿色（成功）或红色（失败）指示器
