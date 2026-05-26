## 1. 迁移 ImageViewerWindow 到 MaterialClient.UI

- [ ] 1.1 将 `MaterialClient/ViewModels/ImageViewerViewModel.cs` 复制到 `MaterialClient.UI/ViewModels/ImageViewerViewModel.cs`，更新命名空间为 `MaterialClient.UI.ViewModels`，继承 `MaterialClient.UI.ViewModels.ViewModelBase`
- [ ] 1.2 将 `MaterialClient/Views/ImageViewerWindow.axaml` 复制到 `MaterialClient.UI/Views/ImageViewerWindow.axaml`，更新 `x:Class` 为 `MaterialClient.UI.Views.ImageViewerWindow`，更新 `xmlns:vm` 为 `using:MaterialClient.UI.ViewModels`，移除 `Icon="/Assets/fd-ico.ico"` 属性
- [ ] 1.3 将 `MaterialClient/Views/ImageViewerWindow.axaml.cs` 复制到 `MaterialClient.UI/Views/ImageViewerWindow.axaml.cs`，更新命名空间为 `MaterialClient.UI.Views`，更新 `using` 引用
- [ ] 1.4 删除 `MaterialClient` 项目中的原文件：`Views/ImageViewerWindow.axaml`、`Views/ImageViewerWindow.axaml.cs`、`ViewModels/ImageViewerViewModel.cs`
- [ ] 1.5 更新 `MaterialClient/ViewModels/PhotoGridViewModel.cs` 的 `using` 引用，从 `MaterialClient.Views` / `MaterialClient.ViewModels` 改为 `MaterialClient.UI.Views` / `MaterialClient.UI.ViewModels`
- [ ] 1.6 更新 `MaterialClient/ViewModels/AttendedWeighingViewModel.cs` 的 `using` 引用，同上
- [ ] 1.7 验证 MaterialClient 主项目编译通过，PhotoGridView 点击图片可正常打开查看器

## 2. Urban 图片侧边栏点击交互

- [ ] 2.1 在 `UrbanAttendedWeighingViewModel.cs` 中添加 `IServiceProvider` 字段（如未有），新增 `OpenLprImageViewerCommand` 和 `OpenCameraImageViewerCommand` 两个 `[ReactiveCommand]`，实现逻辑：检查路径非空 → DI 解析 ImageViewerViewModel → SetImage(path, title) → new ImageViewerWindow(viewModel).Show()
- [ ] 2.2 在 `UrbanAttendedWeighingWindow.axaml` 中，将车牌识别抓拍的 `Image` 控件用 `Button` 包裹，设置 `Background="Transparent"`、`BorderThickness="0"`、`Padding="0"`，绑定 `Command="{Binding OpenLprImageViewerCommand}"`，`CommandParameter="{Binding LprPhotoPath}"`
- [ ] 2.3 在 `UrbanAttendedWeighingWindow.axaml` 中，将摄像头抓拍的 `Image` 控件用同样的 `Button` 包裹，绑定 `Command="{Binding OpenCameraImageViewerCommand}"`，`CommandParameter="{Binding CameraPhotoPath}"`

## 3. 验证

- [ ] 3.1 编译 MaterialClient.Urban 项目，确认无编译错误
- [ ] 3.2 验证 MaterialClient 主项目 PhotoGridView 图片点击功能不受影响
- [ ] 3.3 验证 Urban 项目：选中列表记录 → 侧边栏显示图片 → 点击图片打开查看器 → 查看器标题正确显示"车牌识别抓拍"或"摄像头抓拍"
