## 1. P0 — 运行时阻断修复

- [x] 1.1 在 `Program.cs` 的 `BuildAvaloniaApp()` 链中添加 `.UseReactiveUI()`，位于 `.WithInterFont().LogToTrace()` 之后
- [x] 1.2 在 `MaterialClientUrbanModule.ConfigureServices` 中添加 `services.AddHttpClient()`，确保 SoundDeviceService 能解析 `IHttpClientFactory`

## 2. P1 — ABP 注册模式对齐

- [x] 2.1 为 `UrbanAttendedWeighingViewModel` 添加 `ITransientDependency` 接口标记
- [x] 2.2 为 `UrbanAttendedWeighingWindow`（code-behind）添加 `ITransientDependency` 接口标记
- [x] 2.3 从 `MaterialClientUrbanModule.ConfigureServices` 中移除手动注册：`services.AddTransient<UrbanAttendedWeighingViewModel>()` 和 `services.AddSingleton<UrbanAttendedWeighingWindow>()`
- [x] 2.4 验证 ABP 自动扫描能正确解析 ViewModel 和 Window

## 3. P1 — ViewModel 属性风格统一

- [x] 3.1 将 `UrbanAttendedWeighingViewModel` 中所有手写 `RaiseAndSetIfChanged` 属性替换为 `[Reactive]` Source Generator 注解
- [x] 3.2 将 `List<IDisposable>` 替换为 `CompositeDisposable`，更新所有订阅管理代码
- [x] 3.3 验证所有 `[Reactive]` 属性的绑定在 UI 中正常工作

## 4. P1 — 代码风格对齐

- [x] 4.1 `Program` 类添加 `internal sealed` 修饰符
- [x] 4.2 `MaterialClientUrbanModule.cs` 命名空间从 file-scoped (`namespace MaterialClient.Urban;`) 改为 block-scoped (`namespace MaterialClient.Urban { }`)
- [x] 4.3 `UrbanAttendedWeighingWindow.axaml.cs` 中事件处理方法重命名：`OnMinimizeClick` → `OnMinimizeButtonClick`，`OnCloseClick` → `OnCloseButtonClick`，同步更新 XAML 中的 `x:Name` 或 `Click` 绑定

## 5. P2 — App.axaml 样式资源补充

- [x] 5.1 在 `App.axaml.Resources` 中添加命名颜色画刷：`PrimaryBlue` (#4169E1)、`LightBlue` (#4C82FC)、`BackgroundGray` (#F5F5F5) 等（从 MaterialClient 复制核心颜色）
- [x] 5.2 添加 DataGrid 选中行样式（蓝色选中行 + 左侧蓝色指示条 + 白色文字）
- [x] 5.3 添加 ComboBox focus 蓝色边框样式
- [x] 5.4 添加 CalendarDatePicker focus 蓝色边框样式
- [x] 5.5 在 `UrbanAttendedWeighingWindow.axaml` 中将硬编码色值替换为命名资源引用（`DynamicResource PrimaryBlue` 等）

## 6. P2 — 窗口配置对齐

- [x] 6.1 `UrbanAttendedWeighingWindow.axaml` 的 `SystemDecorations` 从 `BorderOnly` 改为 `None`
- [x] 6.2 添加窗口 Icon：`Icon="/Assets/fd-ico.ico"`（确保 ico 文件存在于 Urban 项目中，如不存在则从 MaterialClient 复制）
- [x] 6.3 `MaterialClient.Urban.csproj` 中 `AvaloniaUseCompiledBindingsByDefault` 从 `false` 改为 `true`，修复因编译绑定检查产生的绑定错误

## 7. P2 — PreConfigureServices 补充

- [x] 7.1 在 `MaterialClientUrbanModule.PreConfigureServices` 中添加 `#if DEBUG` 条件下的 UserSecrets 支持（与 MaterialClientModule 一致）

## 8. 验证

- [x] 8.1 构建并验证无编译错误
- [ ] 8.2 验证应用启动正常，ABP 模块加载成功
- [ ] 8.3 验证 SoundDeviceService 能正常解析 `IHttpClientFactory`
- [ ] 8.4 验证 ReactiveUI 属性绑定在 UI 中正常工作
- [ ] 8.5 验证 DataGrid 选中行样式正确显示
- [ ] 8.6 验证窗口无边框模式正常工作（可拖拽、最小化、关闭）
- [ ] 8.7 验证应用退出时正确清理资源
