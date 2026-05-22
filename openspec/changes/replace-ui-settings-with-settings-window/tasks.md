## 1. MaterialClient.UI — 迁入 main 分支 Settings 实现

- [x] 1.1 在 `MaterialClient.UI.csproj` 添加 `Avalonia.Controls.DataGrid` 包引用
- [x] 1.2 从 `MaterialClient`（对齐 GitHub main）迁入 `SettingsWindow.axaml` / `SettingsWindow.axaml.cs` 至 `MaterialClient.UI/Views/`，调整 `x:Class` 与 `xmlns` 为 `MaterialClient.UI.*`
- [x] 1.3 迁入 `SettingsWindowViewModel.cs`（含 `CameraConfigViewModel`、`LicensePlateRecognitionConfigViewModel`）至 `MaterialClient.UI/ViewModels/`
- [x] 1.4 迁入 `AddCameraDialog` / `AddLprDialog` 及对应 ViewModel 至 `MaterialClient.UI`
- [x] 1.5 迁入 `ScaleUnitConverter`、`LprDeviceTypeConverter`、`StreamTypeConverter` 至 `MaterialClient.UI/Converters/`，并在 `SettingsWindow` 或 `SharedTheme` 中注册资源
- [x] 1.6 迁入或内联 `ViewModelBase`（若 VM 依赖）；确保所有类型为 `ITransientDependency` 且仅依赖 Common + UI
- [x] 1.7 将 `brand-primary-button` 等 `SettingsWindow` 所需样式并入 `Styles/SharedTheme.axaml` 或窗口 `Window.Styles`；处理窗口 `Icon`（可选/由应用设置）

## 2. MaterialClient.UI — 移除弃用 Settings 框架

- [x] 2.1 删除 `Controls/SettingsDialog.*`、`ViewModels/SettingsViewModel.cs`、`Abstractions/ISettingsSection.cs`
- [x] 2.2 删除 `Settings/Sections/*.cs` 与 `Controls/SettingItems/*`
- [x] 2.3 从 `MaterialClientUiModule.cs` 移除全部 `ISettingsSection` 注册
- [x] 2.4 确认 UI 工程无残留对已删类型的引用

## 3. 消费方入口（仅 Settings）

- [x] 3.1 `AttendedWeighingViewModel.OpenSettings` 改为仅解析并显示 `MaterialClient.UI` 的 `SettingsWindow`
- [x] 3.2 `UrbanAttendedWeighingWindow.OnSystemSettingsClick` 改为 `GetRequiredService<SettingsWindow>()` + `ShowDialog`
- [x] 3.3 移除主程序/Urban 对 `SettingsDialog`、`SettingsViewModel`、`ISettingsSection` 的 using 与调用

## 4. MaterialClient 主工程清理

- [x] 4.1 删除已迁入 UI 的重复文件：`Views/SettingsWindow.*`、`ViewModels/SettingsWindowViewModel.cs`、Settings 相关 Dialogs/Converters（若已迁移）
- [x] 4.2 修正 `MaterialClient` 内仍引用旧命名空间的 XAML/代码（若有）

## 5. 验证

- [x] 5.1 `dotnet build` MaterialClient 与 MaterialClient.Urban 解决方案通过
- [ ] 5.2 主程序：打开设置 → 七个分区内容完整 → 保存后地磅设置可再次打开验证
- [ ] 5.3 Urban：打开设置 → 七个分区可见 → 保存无异常
- [x] 5.4 运行 `openspec validate replace-ui-settings-with-settings-window --strict`
