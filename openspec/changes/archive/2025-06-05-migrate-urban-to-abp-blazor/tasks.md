## 1. Module Configuration & Routing

- [x] 1.1 Change `AddControllersWithViews()` to `AddControllers()` in `UrbanManagementAppModule.ConfigureServices` and remove `AddRazorPages().AddRazorRuntimeCompilation()` registration
- [x] 1.2 Update endpoint routing in `OnApplicationInitializationAsync`: change Blazor fallback from `MapFallbackToPage("/blazor/{**catchall}", "/_Host")` to `MapFallbackToPage("/{**catchall}", "/_Host")`, remove the default MVC route `"{controller=Home}/{action=Index}/{id?}"`
- [x] 1.3 Update `_Host.cshtml` to serve as the default route entry point (remove any `/blazor` path references)
- [x] 1.4 Update `App.razor` router — change DeviceStatus page route from `/blazor/device-status` to `/device-status`

## 2. Admin Layout Component

- [x] 2.1 Create `AdminLayout.razor` implementing `LayoutComponentBase` with: fixed sidebar (nav links to `/`, `/projects`, `/weighing`, `/clients`, `/device-status`), top toolbar (refresh + fullscreen + admin indicator), horizontal tab bar tracking opened pages with close buttons, and `@Body` content area
- [x] 2.2 Update `MainLayout.razor` to delegate to `AdminLayout.razor` (or replace its content with admin layout structure)
- [x] 2.3 Update `admin.css` — remove iframe-related styles (`.layui-tab-item iframe`, iframe sizing rules), keep sidebar/header/tab/card styles intact

## 3. Dashboard Page

- [x] 3.1 Create `Dashboard.razor` at route `/` with: 4 statistics cards (今日数, 出勤数, 在岗数, 在册数) and a recent activity feed list
- [x] 3.2 Add ECharts initialization via `IJSRuntime` JS interop: create `wwwroot/js/echarts-init.js` with `initDashboardChart` and `disposeChart` functions, call from `OnAfterRenderAsync` / `DisposeAsync`

## 4. Project Management Page

- [x] 4.1 Add `GetAsync(Guid id)` method to `IGovProjectAppService` and `GovProjectAppService` — fetch single project by ID for the edit dialog
- [x] 4.2 Create `ProjectManagement.razor` at route `/projects` with: search input, paginated table (项目名称, 施工许可证号, 对接码, 同步状态, 最后同步时间, 操作), inject `IGovProjectAppService` for all data operations
- [x] 4.3 Implement project CRUD dialogs: create modal (项目名称 + 对接码 + 施工许可证号), edit modal (pre-populate from `GetAsync`), delete confirmation, sync status toggle — all calling `IGovProjectAppService` methods directly

## 5. Client Management Pages

- [x] 5.1 Create `ClientList.razor` at route `/clients` with: keyword search input, paginated table (客户端名称, 连接状态, 连接时间, 断开时间, 详情 link), inject `IDeviceStatusAppService`, SignalR connection for `ClientConnectionUpdate` events with fallback polling
- [x] 5.2 Create `ClientDetail.razor` at route `/clients/{proId}` with: back navigation link, 5 device status cards (Scale, Camera, LPR, Sound, Printer), inject `IDeviceStatusAppService`, SignalR subscription filtered by ProId with fallback polling
- [x] 5.3 Add SignalR connection status indicator and last heartbeat display to both client pages

## 6. Weighing Record Page

- [x] 6.1 Create `WeighingRecord.razor` at route `/weighing` with: plate number + project name search inputs, paginated table with all columns (车牌号, 重量, 称重时间, 项目名, 对接码, 数据质量, 同步状态, 重试次数, 同步时间, 操作), inject `IUrbanWeighingRecordAppService`
- [x] 6.2 Implement sync status and anomaly badge rendering (sync type → colored badge, isAnomaly → colored badge)
- [x] 6.3 Implement approval modal dialog: load images via `GetApprovalAttachmentsAsync`, plate number + weight input fields with validation, call `ApproveAsync` on submit

## 7. DeviceStatus Page Update

- [x] 7.1 Update `DeviceStatus.razor` route from `/blazor/device-status` to `/device-status` and ensure it renders correctly within `AdminLayout`

## 8. MVC Cleanup

- [x] 8.1 Delete MVC page controllers: `HomeController.cs`, `MainPageController.cs`, `ProjectController.cs`, `ClientManagementController.cs`, `UrbanWeighingRecordController.cs`
- [x] 8.2 Delete `GovProjectApiController.cs` (duplicate of `GovProjectAppService`)
- [x] 8.3 Delete all cshtml view files: `Views/Home/`, `Views/MainPage/`, `Views/Project/`, `Views/ClientManagement/`, `Views/UrbanWeighingRecord/`, `Views/Shared/_Layout.cshtml`, `Views/_ViewImports.cshtml`, `Views/_ViewStart.cshtml`
- [x] 8.4 Verify `LegacyApiController` remains and `POST /Api/Post` still works as the sole MVC endpoint

## 9. Build & Route Verification

- [x] 9.1 Run `dotnet build` and fix any compilation errors from the cleanup
- [x] 9.2 Verify all Blazor page routes render correctly: `/` (Dashboard), `/projects`, `/weighing`, `/clients`, `/clients/{proId}`, `/device-status`
- [x] 9.3 Verify ABP convention API routes still work: `GET /api/app/gov-project`, `GET /api/app/device-status/client-list`, `GET /api/app/urban-weighing-record`
- [x] 9.4 Verify SignalR hub endpoint `/hubs/devicestatus` is still accessible
