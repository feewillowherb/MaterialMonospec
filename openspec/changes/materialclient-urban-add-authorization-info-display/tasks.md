## 1. Migrate ProjectInfoWindow to MaterialClient.UI

- [x] 1.1 Create `MaterialClient.UI/Views/ProjectInfoWindow.axaml` — copy from `MaterialClient/Views/ProjectInfoWindow.axaml`, update root namespace to `MaterialClient.UI.Views`
- [x] 1.2 Create `MaterialClient.UI/Views/ProjectInfoWindow.axaml.cs` — copy from `MaterialClient/Views/ProjectInfoWindow.axaml.cs`, update namespace to `MaterialClient.UI.Views`, keep `ITransientDependency` and constructor DI pattern
- [x] 1.3 Create `MaterialClient.UI/ViewModels/ProjectInfoWindowViewModel.cs` — copy from `MaterialClient/ViewModels/ProjectInfoWindowViewModel.cs`, update namespace to `MaterialClient.UI.ViewModels`, verify `IAuthenticationService` / `ILicenseService` / `ISettingsService` imports resolve from `MaterialClient.Common`
- [x] 1.4 Delete `MaterialClient/Views/ProjectInfoWindow.axaml` and `MaterialClient/Views/ProjectInfoWindow.axaml.cs` from the main project
- [x] 1.5 Delete `MaterialClient/ViewModels/ProjectInfoWindowViewModel.cs` from the main project

## 2. Update Main Project Namespace References

- [x] 2.1 Update `MaterialClient/ViewModels/AttendedWeighingViewModel.cs` — replace `using MaterialClient.Views` and `using MaterialClient.ViewModels` references to `ProjectInfoWindow` / `ProjectInfoWindowViewModel` with `MaterialClient.UI.Views` / `MaterialClient.UI.ViewModels`
- [x] 2.2 Grep the main project for any remaining `using MaterialClient.Views` / `using MaterialClient.ViewModels` references to `ProjectInfoWindow` or `ProjectInfoWindowViewModel` and update them
- [x] 2.3 Build the main MaterialClient project (`dotnet build src/MaterialClient/MaterialClient.csproj -o .build-verify`) and verify zero namespace-related errors

## 3. Add "项目信息" Button to MaterialClient.Urban

- [x] 3.1 Add "项目信息" Button in `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` — insert before the "系统设置" button inside the `WeighingWindowBase.MenuItems` StackPanel, use `popup-menu-item-button` class, set `Click="OnProjectInfoClick"`
- [x] 3.2 Add `OnProjectInfoClick` handler in `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml.cs` — resolve `ProjectInfoWindow` from DI, call `InitializeAsync()` on its ViewModel, then `ShowDialog(this)`, wrap in try/catch with error logging (follow `OnSystemSettingsClick` pattern)
- [x] 3.3 Build MaterialClient.Urban project (`dotnet build src/MaterialClient.Urban/MaterialClient.Urban.csproj -o .build-verify`) and verify zero errors

## 4. Build Verification

- [x] 4.1 Full solution build (`dotnet build MaterialClient.sln -o .build-verify` from MaterialClient repo root) — verify zero errors across all three projects (MaterialClient, MaterialClient.UI, MaterialClient.Urban)
