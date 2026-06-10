## Why

经过 Urban 与 MaterialClient 一致性评审（参见 `docs/urban-materialclient-consistency-review.md`），发现 Urban 存在 2 个运行时阻断问题、5 个代码风格不一致问题、6 个 UI 样式缺失问题。其中 P0 问题（缺少 `.UseReactiveUI()` 平台集成、Module 缺少 `services.AddHttpClient()`）直接导致 SoundDeviceService 无法正常工作，RxApp 调度器行为异常。P1 问题导致 Urban 的 ABP 注册模式与主应用不一致，增加维护成本。P2 问题使 Urban UI 无法复用 MaterialClient 的共享样式资源，硬编码色值难以维护。

## What Changes

- **修复 P0 运行时阻断**：在 `Program.cs` 中添加 `.UseReactiveUI()` 平台集成；在 `MaterialClientUrbanModule.ConfigureServices` 中添加 `services.AddHttpClient()` 以支持 SoundDeviceService 的 `IHttpClientFactory` 依赖。
- **对齐 ABP 注册模式**：为 ViewModel 和 Window 添加 `ITransientDependency` 标记，改为 ABP 自动扫描注册，移除 Module 中的手动 `services.AddTransient`/`services.AddSingleton`。Window 注册从 Singleton 改为 Transient，与 MaterialClient 一致。
- **统一 ViewModel 属性风格**：将手写 `RaiseAndSetIfChanged` 属性替换为 `[Reactive]` Source Generator 注解（包已引用但未使用）。
- **统一代码风格**：`Program` 类添加 `internal sealed` 修饰符；命名空间从 file-scoped 改为 block-scoped（与 MaterialClient 一致）；事件处理方法命名统一为 `OnXxxButtonClick` 格式。
- **补充 App.axaml 样式资源**：从 MaterialClient 的 `App.axaml` 复制命名颜色画刷（PrimaryBlue、LightBlue 等），替换 Urban 中的硬编码色值。添加 DataGrid 选中行样式、ComboBox/CalendarDatePicker focus 样式。
- **对齐窗口配置**：`SystemDecorations` 从 `BorderOnly` 改为 `None`（与 MaterialClient 一致）；添加窗口 Icon；`AvaloniaUseCompiledBindingsByDefault` 改为 `true`。
- **补充 PreConfigureServices**：添加 `#if DEBUG` UserSecrets 支持（与 MaterialClient 一致）。

## Capabilities

### Modified Capabilities
- `materialclient-urban-desktop`：修复运行时阻断、对齐 ABP 注册模式、统一代码风格、补充 UI 样式资源、对齐窗口配置。

## Impact

| 区域 | 影响 |
|------|------|
| `MaterialClient.Urban/Program.cs` | 添加 `.UseReactiveUI()`，添加 `internal sealed` |
| `MaterialClient.Urban/MaterialClientUrbanModule.cs` | 添加 `services.AddHttpClient()`，移除手动注册，添加 DEBUG UserSecrets |
| `MaterialClient.Urban/ViewModels/UrbanAttendedWeighingViewModel.cs` | 使用 `[Reactive]` 替换手写属性，添加 `ITransientDependency`，改用 `CompositeDisposable` |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml.cs` | 添加 `ITransientDependency`，事件处理命名统一 |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` | 替换硬编码色值为命名资源，`SystemDecorations="None"` |
| `MaterialClient.Urban/App.axaml` | 添加命名颜色画刷、DataGrid 选中行样式、ComboBox focus 样式 |
| `MaterialClient.Urban/App.axaml.cs` | 调整 Window 解析方式 |
| `MaterialClient.Urban/MaterialClient.Urban.csproj` | `AvaloniaUseCompiledBindingsByDefault` 改为 `true` |
