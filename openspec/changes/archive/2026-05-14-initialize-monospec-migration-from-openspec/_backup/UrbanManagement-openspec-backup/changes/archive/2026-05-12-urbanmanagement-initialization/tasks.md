## 1. Project Structure Setup

- [x] 1.1 Create solution directory structure: `src/UrbanManagement.App/`, `src/UrbanManagement.Core/`, `tests/UrbanManagement.Core.Tests/`
- [x] 1.2 Create `Directory.Build.props` at root with net10.0, Nullable, ImplicitUsings, AutoConstructor
- [x] 1.3 Create `Directory.Packages.props` with Central Package Management (ABP 10.0.1, EF Core 10.0.1, Serilog 4.3.0, AutoConstructor 5.6.0, Volo.Abp.AspNetCore.Mvc 10.0.1)
- [x] 1.4 Create `UrbanManagement.sln` with App, Core, and Core.Tests project references
- [x] 1.5 Create `UrbanManagement.Core.csproj` with ABP Core, EF Core SQLite, and domain packages
- [x] 1.6 Create `UrbanManagement.App.csproj` with Web SDK, ABP AspNetCoreMvc, FrameworkReference Microsoft.AspNetCore.App, and Core project reference

## 2. Core Module and Entity Framework

- [x] 2.1 Create `UrbanManagementCoreModule.cs` depending on AbpEntityFrameworkCoreModule + AbpEntityFrameworkCoreSqliteModule, configuring DbContext and SQLite connection
- [x] 2.2 Create `Entities/Enums/SyncStatus.cs` with Pending=0, Success=1, Failed=2
- [x] 2.3 Create `Entities/GovProject.cs` inheriting Entity\<Guid\> with PascalCase properties (ProName, BuildLicenseNo, FdBuildLicenseNo, AddTime, SyncStatus, LastSyncTime, DeleteStatus)
- [x] 2.4 Create `Entities/GovSyncData.cs` inheriting Entity\<int\> with PascalCase properties (CarNo, GoodsWeight, SnapTime, DeviceId, BuildLicenseNo, SiteType, SyncType, SyncNumber, SnapImages, etc.)
- [x] 2.5 Create `Entities/GovLog.cs` inheriting Entity\<int\> with properties (SyncId, SyncTime, SyncNumber, SyncSource, SyncResult, SyncCode, SyncMsg)
- [x] 2.6 Create `EntityFrameworkCore/UrbanManagementDbContext.cs` inheriting AbpDbContext, configuring DbSet for all entities and Fluent API table mappings (Gov_Project, Gov_SyncData, Gov_Log)
- [x] 2.7 Create `Configuration/AppSettings.cs` with AppName and basic settings

## 3. Sample Data Service

- [x] 3.1 Create `Services/SampleDataProvider.cs` with ISampleDataProvider interface and implementation (ITransientDependency + AutoConstructor)
- [x] 3.2 Implement `GetPagedProjectsAsync` returning 3+ sample GovProject records with varied data
- [x] 3.3 Implement `GetPagedSyncDataAsync` returning 5+ sample GovSyncData records with varied SyncType (0, 1, 2) and SnapImages
- [x] 3.4 Implement `GetSyncLogsAsync` returning 2+ sample GovLog records per sync entry
- [x] 3.5 Implement `GetDashboardStatsAsync` returning sample dashboard statistics

## 4. Web Host Setup

- [x] 4.1 Create `Program.cs` using WebApplication.CreateBuilder with ABP module registration (AddAbp\<UrbanManagementAppModule\>)
- [x] 4.2 Create `UrbanManagementAppModule.cs` depending on CoreModule + AbpAutofacModule, configuring MVC services and middleware pipeline (UseStaticFiles, UseRouting, UseAbpRequestLocalization, MapControllerRoute)
- [x] 4.3 Create `appsettings.json` with SQLite connection string (Data Source=UrbanManagement.db) and Serilog configuration
- [x] 4.4 Configure JSON serialization to use camelCase for controller responses (matching LayUI field names)

## 5. Controllers

- [x] 5.1 Create `Controllers/HomeController.cs` inheriting AbpController with Index and Privacy actions
- [x] 5.2 Create `Controllers/ProjectController.cs` inheriting AbpController with Index (view), Add (view + POST mock), PageList (AJAX from SampleDataProvider), SetStatus (mock toggle), Del (mock delete)
- [x] 5.3 Create `Controllers/SyncInfoController.cs` inheriting AbpController with Index (view), PageList (AJAX from SampleDataProvider), LogList (AJAX from SampleDataProvider)

## 6. View Migration

- [x] 6.1 Create `Views/_ViewImports.cshtml` with necessary tag helpers and using directives
- [x] 6.2 Create `Views/_ViewStart.cshtml` setting default layout
- [x] 6.3 Create `Views/Shared/_Layout.cshtml` — Bootstrap navbar layout migrated from MainPage/Index.cshtml with navigation links (Home, Project, SyncInfo)
- [x] 6.4 Create `Views/Home/Index.cshtml` — Dashboard view with ECharts chart area, 4 statistics cards, and recent activity list (hardcoded sample data)
- [x] 6.5 Create `Views/Project/Index.cshtml` — Project management LayUI table with AJAX to /Project/PageList, add/edit/delete operations, and status toggle
- [x] 6.6 Create `Views/Project/Add.cshtml` — LayUI form with ProName, FdBuildLicenseNo, BuildLicenseNo fields, AJAX POST to /Project/Add
- [x] 6.7 Create `Views/SyncInfo/Index.cshtml` — Sync data LayUI table with AJAX to /SyncInfo/PageList, image viewer, and log list popup

## 7. Static Assets

- [x] 7.1 Copy LayUI framework from source project `public/layui/` to `wwwroot/public/layui/`
- [x] 7.2 Copy custom styles from source project `public/style/` to `wwwroot/public/style/`
- [x] 7.3 Copy Bootstrap and jQuery libraries to `wwwroot/lib/` (or use _Layout CDN references)
- [x] 7.4 Create `wwwroot/css/site.css` with basic styles
- [x] 7.5 Create `wwwroot/js/site.js` with minimal JavaScript

## 8. Project Configuration Files

- [x] 8.1 Create `CLAUDE.md` with project-specific instructions referencing AGENTS.md conventions
- [x] 8.2 Create `AGENTS.md` with coding standards adapted from FluentSample (naming: UrbanManagement, service registration patterns, etc.)
- [x] 8.3 Create `.gitignore` for .NET project (bin/, obj/, .vs/, *.user, etc.)

## 9. Build Verification

- [x] 9.1 Run `dotnet build` on the solution and verify no compilation errors
- [x] 9.2 Run `dotnet run` on the App project and verify Kestrel starts
- [x] 9.3 Verify `/Home/Index` renders the dashboard page
- [x] 9.4 Verify `/Project/Index` renders the project table and AJAX loads sample data
- [x] 9.5 Verify `/Project/Add` renders the add form
- [x] 9.6 Verify `/SyncInfo/Index` renders the sync data table and AJAX loads sample data
- [x] 9.7 Verify static files (LayUI CSS/JS) load correctly from `/public/` paths
