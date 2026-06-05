## MODIFIED Requirements

### Requirement: Blazor Server NuGet 包引用
`UrbanManagement.App.csproj` MUST 引用 `Volo.Abp.AspNetCore.Components.Server` NuGet 包以启用 ABP Blazor Server 集成。`UrbanManagement.Core.csproj` MUST NOT 引用此包。

#### Scenario: App 项目包含 Blazor 包
- **WHEN** 检查 `UrbanManagement.App.csproj` 的包引用
- **THEN** MUST 包含 `Volo.Abp.AspNetCore.Components.Server` 的 `PackageReference`

#### Scenario: Core 项目不含 Blazor 包
- **WHEN** 检查 `UrbanManagement.Core.csproj` 的包引用
- **THEN** MUST NOT 包含 `Volo.Abp.AspNetCore.Components.Server` 的 `PackageReference`

### Requirement: Blazor Server 服务注册
`UrbanManagementAppModule` MUST 在 `ConfigureServices` 中注册 Blazor Server 服务。`UrbanManagementCoreModule` MUST NOT 注册 Blazor Server 服务。

#### Scenario: AppModule 注册 AddServerSideBlazor
- **WHEN** `UrbanManagementAppModule.ConfigureServices` 执行
- **THEN** MUST 调用 `context.Services.AddServerSideBlazor()` 注册 Blazor Server 服务

#### Scenario: CoreModule 不注册 AddServerSideBlazor
- **WHEN** `UrbanManagementCoreModule.ConfigureServices` 执行
- **THEN** MUST NOT 调用 `context.Services.AddServerSideBlazor()`
