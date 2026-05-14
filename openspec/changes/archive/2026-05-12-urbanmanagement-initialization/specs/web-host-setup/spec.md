## ADDED Requirements

### Requirement: Application uses WebApplication host
`Program.cs` SHALL use `WebApplication.CreateBuilder(args)` to create the web host, register ABP via `builder.Services.AddAbp<UrbanManagementAppModule>()`, and configure the HTTP request pipeline with MVC, static files, and routing.

#### Scenario: Application starts as a web server
- **WHEN** `dotnet run` is executed on the App project
- **THEN** Kestrel SHALL start listening on the configured port

#### Scenario: ABP modules are loaded
- **WHEN** the application starts
- **THEN** both `UrbanManagementAppModule` and `UrbanManagementCoreModule` SHALL be initialized

### Requirement: MVC services are registered
The App module SHALL register ASP.NET Core MVC services including controllers with views, Razor runtime compilation (Debug mode only), and the default MVC route pattern `{controller=Home}/{action=Index}/{id?}`.

#### Scenario: Controllers are discoverable
- **WHEN** a request is sent to `/Project/Index`
- **THEN** `ProjectController.Index()` SHALL handle the request

#### Scenario: Views are resolved
- **WHEN** a controller returns `View()`
- **THEN** Razor SHALL locate and render the corresponding `.cshtml` file

### Requirement: Static files middleware is enabled
The application SHALL serve static files from `wwwroot/` via `app.UseStaticFiles()`, enabling access to LayUI framework files, custom styles, and other static assets.

#### Scenario: LayUI CSS is accessible
- **WHEN** a browser requests `/public/layui/css/layui.css`
- **THEN** the file SHALL be served with appropriate content-type

#### Scenario: Custom admin styles are accessible
- **WHEN** a browser requests `/public/style/admin.css`
- **THEN** the file SHALL be served correctly

### Requirement: Controllers inherit from ABP base controller
All MVC controllers SHALL inherit from `AbpController` (from `Volo.Abp.AspNetCore.Mvc`) to gain ABP integration features.

#### Scenario: Controller has access to ABP services
- **WHEN** a controller action executes
- **THEN** ABP `Logger`, `Mapper`, and other base services SHALL be available

### Requirement: App project csproj references ASP.NET Core and ABP MVC packages
`UrbanManagement.App.csproj` SHALL include `Volo.Abp.AspNetCore.Mvc` and a `FrameworkReference` to `Microsoft.AspNetCore.App`.

#### Scenario: ASP.NET Core APIs are available
- **WHEN** the App project compiles
- **THEN** `Controller`, `IActionResult`, `View()`, `Json()` and other MVC APIs SHALL be resolvable
