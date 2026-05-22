## 1. MaterialClient.UI — 转换器迁移

- [x] 1.1 在 `MaterialClient.UI/Converters/` 迁移 `MaterialClient/Converters/` 下全部 12 个 `.cs` 文件，命名空间改为 `MaterialClient.UI.Converters`
- [x] 1.2 将 `Car_Default.png` 加入 `MaterialClient.UI/Assets/`，更新 `MaterialClient.UI.csproj` 的 `AvaloniaResource` 项
- [x] 1.3 更新 `CarNullOrEmptyImageConverter` / `NullOrEmptyImageConverter` 的 `avares://` 与 `/Assets/` 前缀解析为 `MaterialClient.UI`
- [x] 1.4 新建 `MaterialClient.UI/Styles/SharedConverters.axaml`，注册全部转换器（键名与主应用原 App.axaml 一致，含 `ProductCodeConverter`）

## 2. 应用入口 — 共享资源引用

- [x] 2.1 `MaterialClient/App.axaml`：`StyleInclude` 引入 `SharedConverters.axaml`，删除内联 `<converters:*>` 注册块
- [x] 2.2 `MaterialClient.Urban/App.axaml`：`StyleInclude` 引入 `SharedConverters.axaml`
- [x] 2.3 删除 `MaterialClient/Converters/` 目录；全局替换 XAML/C# 中 `MaterialClient.Converters` → `MaterialClient.UI.Converters`（如有）

## 3. MaterialClient.Urban — 照片绑定

- [x] 3.1 `UrbanAttendedWeighingViewModel`：新增 `LprPhotoPath`、`CameraPhotoPath`（及可选拍摄时间）属性，`SelectedRecord` 变化时更新
- [x] 3.2 `UrbanAttendedWeighingWindow.axaml`：两处照片区域改为 `Image` + `CarNullOrEmptyImageConverter` 绑定 ViewModel 路径
- [x] 3.3 移除 emoji `TextBlock` 占位；保留边框/圆角样式

## 4. 验证

- [x] 4.1 `dotnet build` MaterialClient.sln（Debug）— `MaterialClient.UI` 与 `-t:Compile` 目标通过；完整 sln 复制阶段因运行中进程锁定 DLL 失败（需关闭 MaterialClient/Urban 后重试）
- [ ] 4.2 手动验证：Urban 启动后无记录时照片区显示默认车辆图；主应用 `ManualMatchWindow` / `ImageViewerWindow` 图片仍正常
