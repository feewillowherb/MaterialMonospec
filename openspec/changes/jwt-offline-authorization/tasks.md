## 1. 共享依赖

- [x] 1.1 在 `repos/MaterialClient/Directory.Packages.props` 中添加 `System.IdentityModel.Tokens.Jwt` 包版本
- [x] 1.2 在 `repos/UrbanManagement/Directory.Packages.props` 中添加相同包版本
- [x] 1.3 生成 RSA 2048 位密钥对（openssl 或 .NET 工具）用于开发/测试 — 记录生成的密钥用于配置注入

## 2. MaterialClient: JWT 授权验证

- [x] 2.1 创建 `MaterialClient.Common/Services/JwtLicenseChecker.cs` — 实现 `IStaticLicenseChecker`、`ISingletonDependency`、`[AutoConstructor]`；注入 `IConfiguration` 和 `ILogger<JwtLicenseChecker>`；从 `Jwt:PublicKey` PEM 配置加载 RSA 公钥；使用 `JwtSecurityTokenHandler.ValidateToken` 实现 `CheckLicenseAsync`，配置 `TokenValidationParameters`（ValidateIssuer、ValidIssuer="UrbanManagement"、ValidateAudience、ValidAudience="MaterialClient.Urban"、ValidateLifetime=true、IssuerSigningKey=RsaSecurityKey）；提取 Claims（proId、proName、buildLicenseNo、fdBuildLicenseNo、exp）并返回 `LicenseCheckResult` — 实现 `IStaticLicenseChecker`、`ISingletonDependency`、`[AutoConstructor]`；注入 `IConfiguration` 和 `ILogger<JwtLicenseChecker>`；从 `Jwt:PublicKey` PEM 配置加载 RSA 公钥；使用 `JwtSecurityTokenHandler.ValidateToken` 实现 `CheckLicenseAsync`，配置 `TokenValidationParameters`（ValidateIssuer、ValidIssuer="UrbanManagement"、ValidateAudience、ValidAudience="MaterialClient.Urban"、ValidateLifetime=true、IssuerSigningKey=RsaSecurityKey）；提取 Claims（proId、proName、buildLicenseNo、fdBuildLicenseNo、exp）并返回 `LicenseCheckResult`
- [x] 2.2 处理 `JwtLicenseChecker` 中的边界情况: 文件不存在、无效 JWT 格式、签名验证失败、令牌过期 — 均返回包含描述信息的 `LicenseCheckResult.Fail`；构造函数在公钥缺失或无效时记录警告但不抛出异常: 文件不存在、无效 JWT 格式、签名验证失败、令牌过期 — 均返回包含描述信息的 `LicenseCheckResult.Fail`；构造函数在公钥缺失或无效时记录警告但不抛出异常
- [x] 2.3 完整删除 `MaterialClient.Common/Services/RsaLicenseDecryptor.cs`
- [x] 2.4 完整删除 `MaterialClient.Common/Services/StaticLicenseChecker.cs`
- [x] 2.5 编辑 `MaterialClient.Common/Configuration/SystemSettings.cs` — 将 `LicenseFilePath` 默认值从 `"RSA.xml"` 改为 `"license.urban"`
- [x] 2.6 编辑 `MaterialClient.Urban/appsettings.json` — 新增 `Jwt:PublicKey` 配置段，填入 RSA 公钥 PEM 字符串

## 3. MaterialClient: 构建验证

- [x] 3.1 使用 `-o .build-verify` 构建 `MaterialClient.sln`，确认所有变更后编译通过

## 4. UrbanManagement: JWT 授权生成服务

- [x] 4.1 创建 `UrbanManagement.Core/Models/UrbanLicenseRequestDto.cs` — record 包含 `GovProjectId` (Guid)、`ProName` (string)、`BuildLicenseNo` (string)、`FdBuildLicenseNo` (string)、`ExpiresAt` (DateTime)；包含 `static UrbanLicenseRequestDto FromEntity(GovProject project, DateTime expiresAt)` 工厂方法 — record 包含 `GovProjectId` (Guid)、`ProName` (string)、`BuildLicenseNo` (string)、`FdBuildLicenseNo` (string)、`ExpiresAt` (DateTime)；包含 `static UrbanLicenseRequestDto FromEntity(GovProject project, DateTime expiresAt)` 工厂方法
- [x] 4.2 创建 `UrbanManagement.Core/Services/UrbanLicenseGenerator.cs` — `IUrbanLicenseGenerator` 接口，包含 `string GenerateLicenseToken(UrbanLicenseRequestDto request)` 方法；`UrbanLicenseGenerator` 实现类，标记 `ITransientDependency`、`[AutoConstructor]`；注入 `IConfiguration`；构造函数中从 `Jwt:PrivateKey` PEM 配置加载 RSA 私钥（缺失或无效时抛出 `InvalidOperationException`）；使用 `JwtSecurityToken` 实现 `GenerateLicenseToken`，包含 Claims（proId、proName、buildLicenseNo、fdBuildLicenseNo、exp 为 Unix 时间戳、jti 为 Guid、iss="UrbanManagement"、aud="MaterialClient.Urban"）和 `SigningCredentials(RsaSecurityKey, SecurityAlgorithms.RsaSha256)` — `IUrbanLicenseGenerator` 接口，包含 `string GenerateLicenseToken(UrbanLicenseRequestDto request)` 方法；`UrbanLicenseGenerator` 实现类，标记 `ITransientDependency`、`[AutoConstructor]`；注入 `IConfiguration`；构造函数中从 `Jwt:PrivateKey` PEM 配置加载 RSA 私钥（缺失或无效时抛出 `InvalidOperationException`）；使用 `JwtSecurityToken` 实现 `GenerateLicenseToken`，包含 Claims（proId、proName、buildLicenseNo、fdBuildLicenseNo、exp 为 Unix 时间戳、jti 为 Guid、iss="UrbanManagement"、aud="MaterialClient.Urban"）和 `SigningCredentials(RsaSecurityKey, SecurityAlgorithms.RsaSha256)`
- [x] 4.3 创建 `UrbanManagement.Core/Services/GovProjectLicenseAppService.cs` — `IGovProjectLicenseAppService` 接口，包含 `Task<FileContentResult> GenerateAsync(Guid govProjectId, DateTime expiresAt)`；实现类继承 `ApplicationService`、`[AutoConstructor]`；注入 `IUrbanLicenseGenerator` 和 `IRepository<GovProject, Guid>`；加载项目，通过 `UrbanLicenseRequestDto.FromEntity` 构建请求，调用生成器，返回 `FileContentResult`（内容类型 `application/octet-stream`，`attachment; filename="license.urban"`）；项目不存在或已软删除时抛出 `EntityNotFoundException` — `IGovProjectLicenseAppService` 接口，包含 `Task<FileContentResult> GenerateAsync(Guid govProjectId, DateTime expiresAt)`；实现类继承 `ApplicationService`、`[AutoConstructor]`；注入 `IUrbanLicenseGenerator` 和 `IRepository<GovProject, Guid>`；加载项目，通过 `UrbanLicenseRequestDto.FromEntity` 构建请求，调用生成器，返回 `FileContentResult`（内容类型 `application/octet-stream`，`attachment; filename="license.urban"`）；项目不存在或已软删除时抛出 `EntityNotFoundException`

## 5. UrbanManagement: 配置

- [x] 5.1 编辑 `UrbanManagement.App/appsettings.json` — 新增 `Jwt:PrivateKey` 配置段，填入 RSA 私钥 PEM 字符串

## 6. UrbanManagement: 授权生成管理后台 UI

- [x] 6.1 创建 Blazor 页面/组件用于授权生成: 下拉框选择 GovProject（通过 `IGovProjectAppService.GetListAsync` 分页查询），展示所选项目详情（ProName、BuildLicenseNo、AuthEndTime），过期日期选择器默认为项目的 AuthEndTime，"生成并下载"按钮在未选择项目时禁用
- [x] 6.2 连接生成按钮调用 `IGovProjectLicenseAppService.GenerateAsync`，触发浏览器文件下载，展示成功/失败反馈

## 7. UrbanManagement: 构建验证

- [x] 7.1 构建 `UrbanManagement.sln`，确认所有变更后编译通过
