## MODIFIED Requirements

### Requirement: App module depends on Core and Autofac
`UrbanManagementAppModule` SHALL depend on `UrbanManagementCoreModule` and `AbpAutofacModule`。App 模块 SHALL 仅注册 API 控制器（不含视图引擎），并注册 Blazor Server 作为主 UI 框架。

#### Scenario: ABP module chain is valid
- **WHEN** the application starts
- **THEN** the module dependency chain SHALL be: AppModule → CoreModule → AbpEntityFrameworkCoreModule

#### Scenario: App module registers API controllers only
- **WHEN** `UrbanManagementAppModule.ConfigureServices` executes
- **THEN** it SHALL call `context.Services.AddControllers()` (not `AddControllersWithViews()`)
- **AND** it SHALL call `context.Services.AddServerSideBlazor()` for Blazor Server UI
- **AND** it MUST NOT register Razor view engine services

#### Scenario: LegacyApiController remains functional
- **WHEN** the application starts
- **THEN** `LegacyApiController` SHALL be accessible via MVC convention routing at `/Api/Post`
- **AND** no other MVC page controllers SHALL exist
