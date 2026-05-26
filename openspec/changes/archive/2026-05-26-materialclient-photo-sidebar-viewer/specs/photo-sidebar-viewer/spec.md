## ADDED Requirements

### Requirement: ImageViewerWindow 迁移到 MaterialClient.UI 共享项目

`ImageViewerWindow` 和 `ImageViewerViewModel` SHALL 从 `MaterialClient` 项目迁移到 `MaterialClient.UI` 共享项目，使 `MaterialClient` 和 `MaterialClient.Urban` 均可直接使用。

**实现约束**: 迁移后命名空间从 `MaterialClient.Views` / `MaterialClient.ViewModels` 变更为 `MaterialClient.UI.Views` / `MaterialClient.UI.ViewModels`。

#### Scenario: 迁移后 MaterialClient 主项目可正常打开图片查看器

- **WHEN** 在 MaterialClient 主项目中点击 PhotoGridView 的照片缩略图
- **THEN** 系统 SHALL 正常打开 ImageViewerWindow 并显示图片
- **AND** 缩放、拖拽、最大化功能 SHALL 保持不变

#### Scenario: 迁移后 MaterialClient.Urban 可打开图片查看器

- **WHEN** 在 MaterialClient.Urban 项目中通过 DI 解析 ImageViewerViewModel 并 new ImageViewerWindow(viewModel).Show()
- **THEN** 系统 SHALL 正常打开 ImageViewerWindow 并显示图片

#### Scenario: 迁移后 ABP DI 注册仍有效

- **WHEN** MaterialClient 或 MaterialClient.Urban 应用启动
- **THEN** ABP SHALL 自动扫描并注册 ImageViewerViewModel 和 ImageViewerWindow（标注了 ITransientDependency）

---

### Requirement: 图片侧边栏照片可点击查看详情

Urban 图片侧边栏中的车牌识别抓拍和摄像头抓拍照片 SHALL 支持点击打开全屏图片查看器。

#### Scenario: 点击车牌识别抓拍图片打开查看器

- **WHEN** 用户在图片侧边栏中点击车牌识别抓拍照片
- **AND** LprPhotoPath 不为空
- **THEN** 系统 SHALL 打开 ImageViewerWindow
- **AND** 标题 SHALL 显示"车牌识别抓拍"
- **AND** 图片 SHALL 加载 LprPhotoPath 指向的图片文件

#### Scenario: 点击摄像头抓拍图片打开查看器

- **WHEN** 用户在图片侧边栏中点击摄像头抓拍照片
- **AND** CameraPhotoPath 不为空
- **THEN** 系统 SHALL 打开 ImageViewerWindow
- **AND** 标题 SHALL 显示"摄像头抓拍"
- **AND** 图片 SHALL 加载 CameraPhotoPath 指向的图片文件

#### Scenario: 图片路径为空时不打开查看器

- **WHEN** 用户点击图片区域
- **AND** 对应的图片路径为 null 或空字符串
- **THEN** 系统 SHALL NOT 打开 ImageViewerWindow
- **AND** 不 SHALL 抛出异常

#### Scenario: 未选中列表记录时点击图片

- **WHEN** 用户未选中任何列表记录
- **THEN** 图片区域 SHALL 显示默认占位图（通过 CarNullOrEmptyImageConverter）
- **AND** 点击占位图 SHALL NOT 打开查看器

---

### Requirement: 图片点击使用 MVVM 命令绑定

图片点击交互 SHALL 通过 ReactiveUI 的 ReactiveCommand 实现，遵循 MVVM 模式。

#### Scenario: 命令定义在 ViewModel 中

- **WHEN** ViewModel 初始化完成
- **THEN** ViewModel SHALL 提供 `OpenLprImageViewerCommand`（车牌识别图片）和 `OpenCameraImageViewerCommand`（摄像头图片）两个 ReactiveCommand
- **AND** 命令参数为图片路径字符串

#### Scenario: 命令通过 DI 解析 ImageViewerViewModel

- **WHEN** 图片点击命令执行且路径非空
- **THEN** 系统 SHALL 通过 IServiceProvider.GetRequiredService<ImageViewerViewModel>() 解析 ViewModel
- **AND** 调用 viewModel.SetImage(path, title) 设置图片路径和标题
- **AND** 创建 new ImageViewerWindow(viewModel) 并调用 window.Show()

#### Scenario: 图片查看器打开异常时优雅降级

- **WHEN** 打开图片查看器过程中发生异常（如文件不存在、权限不足）
- **THEN** 系统 SHALL NOT 崩溃
- **AND** SHALL 记录错误日志
