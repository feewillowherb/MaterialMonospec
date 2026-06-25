## ADDED Requirements

### Requirement: LicenseInfo AccessCode 实体迁移

`LicenseInfo` 实体 SHALL 将 `BuildLicenseNo` 属性重命名为 `AccessCode`，表示城管接入码（与 `GovProject.AccessCode` / BasePlatform `accessCode` 语义一致）。EF Core Migration SHALL 执行列重命名。

#### Scenario: 实体属性定义

- **WHEN** 查看 `MaterialClient.Common/Entities/LicenseInfo.cs`
- **THEN** SHALL 存在 `public string? AccessCode { get; set; }`
- **AND** MUST NOT 存在 `BuildLicenseNo` 属性

#### Scenario: EF Migration 重命名列

- **WHEN** 应用 EF Core Migration
- **THEN** 数据库 `LicenseInfo` 表 SHALL 将原 `BuildLicenseNo` 列重命名为 `AccessCode`
- **AND** 已有数据 SHALL 保留在重命名后的列中

### Requirement: 删除 FdBuildLicenseNo 字段

系统 SHALL 从 `LicenseInfo` 实体、EF 模型、Migration 及所有业务代码中**彻底删除** `FdBuildLicenseNo`。JWT 验签、SignalR 同步、启动持久化 MUST NOT 读取、写入或引用该字段。

#### Scenario: 实体无 FdBuildLicenseNo

- **WHEN** 查看 `LicenseInfo` 实体定义
- **THEN** MUST NOT 存在 `FdBuildLicenseNo` 属性

#### Scenario: Migration 删除列

- **WHEN** 应用 EF Core Migration
- **THEN** SHALL 从 `LicenseInfo` 表删除 `FdBuildLicenseNo` 列（若存在）

#### Scenario: 代码无 FdBuildLicenseNo 引用

- **WHEN** 在 `MaterialClient.Common` 与 `MaterialClient.Urban` 中搜索 `FdBuildLicenseNo`
- **THEN** MUST NOT 存在业务逻辑引用（注释中说明历史映射除外）

### Requirement: 删除 AuthToken 字段

系统 SHALL 从 `LicenseInfo` 实体及所有 Urban 5001 授权流程中删除 `AuthToken`。Urban 产品 MUST NOT 通过 `VerifyAuthorizationCodeAsync` 直连 BasePlatform 激活。

#### Scenario: 实体无 AuthToken

- **WHEN** 查看 `LicenseInfo` 实体定义
- **THEN** MUST NOT 存在 `AuthToken` 属性

#### Scenario: Migration 删除 AuthToken 列

- **WHEN** 应用 EF Core Migration
- **THEN** SHALL 从 `LicenseInfo` 表删除 `AuthToken` 列（若存在）

### Requirement: Wire 名 buildLicenseNo 映射到 AccessCode

来自 Hub JSON、政府上传 DTO 等外部协议的 `buildLicenseNo` 字段 SHALL 在映射层写入 `LicenseInfo.AccessCode`，MUST NOT 在域模型中保留 `BuildLicenseNo` 属性名。

#### Scenario: Hub DTO 映射

- **WHEN** `DeviceStatusSignalRClient` 收到 `ClientProjectLicenseInfoDto` 且 `buildLicenseNo` 有值
- **THEN** SHALL 将值写入 `LicenseInfo.AccessCode`
- **AND** MUST NOT 写入已删除的 `FdBuildLicenseNo`

#### Scenario: 称重上传 DTO

- **WHEN** `UrbanServerUploadService` 构建政府协议出站 payload
- **THEN** `buildLicenseNo` 字段值 SHALL 取自 `LicenseInfo.AccessCode`

### Requirement: LicenseCheckResult 使用 AccessCode

`LicenseCheckResult`（或等价验权结果类型）SHALL 将原 `BuildLicenseNo` 属性改名为 `AccessCode`，反映 JWT claim `accessCode` 的提取结果。

#### Scenario: 验权结果属性

- **WHEN** `IStaticLicenseChecker` 验签成功
- **THEN** `LicenseCheckResult` SHALL 暴露 `AccessCode` 属性
- **AND** MUST NOT 暴露 `BuildLicenseNo` 或 `FdBuildLicenseNo`
