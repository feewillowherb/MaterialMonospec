## 1. 项目搭建

- [x] 1.1 创建 `MaterialClient.UI/MaterialClient.UI.csproj` 作为 Avalonia 类库（net10.0, Nullable, ImplicitUsings, CompiledBindingsByDefault, EnableAvaloniaXamlCompilation），包含 Avalonia、ReactiveUI 包引用及对 MaterialClient.Common 的 ProjectReference
- [x] 1.2 将 MaterialClient.UI 项目添加到 `MaterialClient.sln`
- [x] 1.3 在 MaterialClient.csproj 和 MaterialClient.Urban.csproj 中添加 `<ProjectReference Include="..\MaterialClient.UI\MaterialClient.UI.csproj" />`
- [x] 1.4 创建目录结构：`Controls/`、`ViewModels/`、`Styles/`、`Abstractions/`、`Models/`
- [x] 1.5 验证解决方案在所有三个项目引用下可成功构建

## 2. 共享主题资源字典

- [x] 2.1 创建 `MaterialClient.UI/Styles/SharedTheme.axaml`，定义命名颜色资源：PrimaryBlue (#4169E1)、LightBlue (#4A85F9)、BackgroundGray (#F5F5F5)、SuccessGreen (#22C55E)、ErrorRed (#EF4444)
- [x] 2.2 在 SharedTheme.axaml 中添加共享按钮样式类：primary-button（正常 + 禁用态）、titlebar-close-button、titlebar-minimize-button、tab-button
- [x] 2.3 添加共享边框/卡片样式类：card-border、section-border
- [x] 2.4 更新 MaterialClient/App.axaml，通过 MergedDictionaries 导入 SharedTheme.axaml 并移除重复的样式定义
- [x] 2.5 更新 MaterialClient.Urban/App.axaml，通过 MergedDictionaries 导入 SharedTheme.axaml 并移除重复的样式定义
- [x] 2.6 验证两个应用使用共享主题后渲染正常（无视觉回归）

## 3. DeviceStatusBar 控件

- [x] 3.1 创建 `MaterialClient.UI/Models/DeviceStatusItem.cs`，定义为 `record DeviceStatusItem(string Name, bool IsOnline)`
- [x] 3.2 创建 `MaterialClient.UI/Controls/DeviceStatusBar.axaml` 作为 TemplatedControl，包含 ItemsSource 依赖属性和模板（水平 ItemsControl，每项含彩色圆圈 + 文本）
- [x] 3.3 创建 `MaterialClient.UI/Controls/DeviceStatusBar.axaml.cs` 代码隐藏文件，注册 ItemsSource AvaloniaProperty
- [x] 3.4 创建 `MaterialClient.UI/ViewModels/DeviceStatusBarViewModel.cs`，包含 ObservableCollection<DeviceStatusItem> Devices 属性，使用 [AutoConstructor] 注入 ILocalEventBus，注册 ITransientDependency
- [x] 3.5 在 DeviceStatusBarViewModel 构造函数中实现初始设备状态加载（查询设备服务接口）
- [x] 3.6 在 DeviceStatusBarViewModel 中实现 ILocalEventHandler 处理设备状态变更事件

## 4. DeviceStatusBar 集成

- [x] 4.1 在 MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml 中用 `<ui:DeviceStatusBar>` 控件替换内联设备状态栏
- [x] 4.2 在 UrbanAttendedWeighingViewModel 中将 DeviceStatusBar 的 DataContext 连接到 DeviceStatusBarViewModel
- [x] 4.3 配置 Urban 的 DeviceStatusBarViewModel 显示地磅、摄像头、车牌识别设备指示器
- [x] 4.4 在 MaterialClient/Views/AttendedWeighing/AttendedWeighingWindow.axaml 中用 `<ui:DeviceStatusBar>` 控件替换内联设备状态栏
- [x] 4.5 在主应用的 AttendedWeighingWindow 中连接 DeviceStatusBar 的 DataContext
- [x] 4.6 配置主应用的 DeviceStatusBarViewModel 显示地磅、摄像头、USB摄像头、打印机、音频设备、车牌识别指示器
- [x] 4.7 验证两个应用中设备连接/断开时状态指示器正确更新

## 5. 设置框架 — 抽象与基类

- [x] 5.1 创建 `MaterialClient.UI/Abstractions/ISettingsSection.cs` 接口：DisplayName (string)、CreateView() (Control)、LoadAsync(CancellationToken)、SaveAsync(CancellationToken)、IsDirty (bool)
- [x] 5.2 创建 `MaterialClient.UI/ViewModels/SettingsViewModel.cs` 基类，包含：Sections (ObservableCollection<ISettingsSection>)、SelectedSection、SaveCommand (ReactiveCommand)、IsDirty 聚合
- [x] 5.3 实现 SettingsViewModel 构造函数，通过 IServiceProvider/ABP 容器解析所有 ISettingsSection 实现

## 6. 设置框架 — 对话框与设置项控件

- [x] 6.1 创建 `MaterialClient.UI/Controls/SettingsDialog.axaml` 作为 Window，包含：标题栏、左侧导航 ListBox 绑定到 Sections、右侧内容 ContentControl 绑定到 SelectedSection.CreateView()、底部保存按钮
- [x] 6.2 创建 `MaterialClient.UI/Controls/SettingsDialog.axaml.cs` 代码隐藏文件，实现窗口拖动、关闭、Escape 键处理
- [x] 6.3 创建 `MaterialClient.UI/Controls/SettingItems/ToggleSettingItem.axaml` — 标签 + ToggleSwitch 绑定到布尔值
- [x] 6.4 创建 `MaterialClient.UI/Controls/SettingItems/DropdownSettingItem.axaml` — 标签 + ComboBox 绑定到选项列表
- [x] 6.5 创建 `MaterialClient.UI/Controls/SettingItems/SliderSettingItem.axaml` — 标签 + Slider + 值显示，支持 Min/Max/Step
- [x] 6.6 创建 `MaterialClient.UI/Controls/SettingItems/TextSettingItem.axaml` — 标签 + TextBox 绑定到字符串值

## 7. 设置分区 — Urban

- [x] 7.1 创建 `MaterialClient.Urban/Views/Settings/` 目录用于 Urban 特定设置分区
- [x] 7.2 实现 Urban ScaleSection : ISettingsSection, ITransientDependency（地磅串口、波特率、自动归零开关）
- [x] 7.3 实现 Urban CameraSection : ISettingsSection, ITransientDependency（摄像头配置）
- [x] 7.4 实现 Urban LprSection : ISettingsSection, ITransientDependency（车牌识别设备设置、JPEG 质量滑块）
- [x] 7.5 实现 Urban SystemSection : ISettingsSection, ITransientDependency（开机自启开关、通用设置）
- [x] 7.6 将 UrbanAttendedWeighingWindow 中的"系统设置"按钮连接到打开 SettingsDialog（使用解析的 SettingsViewModel）
- [x] 7.7 验证 Urban 设置对话框可打开、显示所有分区、加载当前值并保存更改

## 8. 设置分区 — 主应用迁移

- [x] 8.1 创建 `MaterialClient/Views/Settings/` 目录用于主应用设置分区
- [x] 8.2 从 SettingsWindowViewModel 中提取 ScaleSettings 为 ScaleSection : ISettingsSection, ITransientDependency
- [x] 8.3 提取 WeighingSettings 为 WeighingSection : ISettingsSection, ITransientDependency
- [x] 8.4 提取 CameraSettings 为 CameraSection : ISettingsSection, ITransientDependency
- [x] 8.5 提取 LprSettings 为 LprSection : ISettingsSection, ITransientDependency
- [x] 8.6 提取 SystemSettings 为 SystemSection : ISettingsSection, ITransientDependency
- [x] 8.7 提取 SoundDeviceSettings 为 SoundDeviceSection : ISettingsSection, ITransientDependency
- [x] 8.8 提取 PrinterSettings 为 PrinterSection : ISettingsSection, ITransientDependency
- [x] 8.9 更新 MaterialClient 主应用的"系统设置"按钮以打开 SettingsDialog
- [x] 8.10 验证主应用设置对话框可打开、显示全部 7 个分区、加载当前值并保存更改

## 9. 清理与验证

- [x] 9.1 从两个窗口文件中移除废弃的内联状态栏 XAML
- [x] 9.2 从 App.axaml 文件中移除现已包含在 SharedTheme.axaml 中的废弃样式定义
- [x] 9.3 验证 MaterialClient 使用共享组件后可构建并运行
- [x] 9.4 验证 MaterialClient.Urban 使用共享组件后可构建并运行
- [x] 9.5 验证硬件状态变更时两个应用的设备状态栏实时更新
- [x] 9.6 验证两个应用的设置持久化正常工作（加载/保存循环）
