## 1. 项目基础设施

- [x] 1.1 创建 MaterialClient.Urban 项目结构
  - 创建 `MaterialClient.Urban/MaterialClient.Urban.csproj`
  - 配置 .NET 10 目标框架
  - 添加 Avalonia、ReactiveUI、MaterialClient.Common 项目引用
- [x] 1.2 添加 Urban 项目到解决方案
  - 修改 `MaterialClient.sln` 添加 Urban 项目
  - 验证解决方案可正常编译
- [x] 1.3 创建 Urban 应用启动配置
  - 创建 `MaterialClient.Urban/App.axaml`
  - 创建 `MaterialClient.Urban/App.axaml.cs`
  - 实现 `OnFrameworkInitializationCompleted` 启动逻辑
  - 配置全局样式和资源

## 2. 枚举与配置更新

- [x] 2.1 扩展 WeighingMode 枚举
  - 修改 `MaterialClient.Common/Entities/Enums/WeighingMode.cs`
  - 添加 `UrbanMode = 201` 枚举值
  - 添加 Description 特性"城管专用模式"
- [x] 2.2 扩展 ProductCode 枚举
  - 修改 `MaterialClient.Common/Entities/Enums/ProductCode.cs`
  - 添加 `Urban = 5030` 枚举值
  - 添加 Description 特性"城管专用产品代码"
- [x] 2.3 扩展 SystemSettings 配置
  - 修改 `MaterialClient.Common/Configuration/SystemSettings.cs`
  - 添加 `IsUrbanMode` 配置项
  - 添加 `UrbanProductCode` 配置项
  - 添加 `LicenseFilePath` 配置项
- [x] 2.4 扩展 AttachmentType 枚举
  - 修改 `MaterialClient.Common/Entities/Attachment.cs`
  - 添加 `AttachType.Lrp = 5` 枚举值
  - 添加 Description 特性"车牌识别图片"
  - 确保 Lrp 类型与其他附件类型兼容
- [x] 2.5 修改 HikvisionLprService 保存 Lrp 附件
  - 修改 `MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs`
  - 检查当前 WeighingMode 是否为 UrbanMode (201)
  - 仅 UrbanMode 时保存 Lrp 类型的 Attachment
  - 使用 `JpegCompressionUtil.TryCompressJpegBytes` 压缩 Lrp 图片
- [x] 2.6 修改 VzvisionLprService 保存 Lrp 附件
  - 修改 `MaterialClient.Common/Services/Vzvision/VzvisionLprService.cs`
  - 检查当前 WeighingMode 是否为 UrbanMode (201)
  - 仅 UrbanMode 时保存 Lrp 类型的 Attachment
  - 使用 `JpegCompressionUtil.TryCompressJpegBytes` 压缩 Lrp 图片
- [x] 2.7 增强 JpegCompressionUtil 支持 Lrp 压缩
  - 修改 `MaterialClient.Common/Utils/JpegCompressionUtil.cs`
  - 为 Lrp 图片配置合适的压缩质量参数
  - 确保 Lrp 图片压缩后保持车牌识别清晰度

## 3. 静态授权检查

- [x] 3.1 创建 IStaticLicenseChecker 接口
  - 在 `MaterialClient.Common/Services/` 创建接口
  - 定义 `CheckLicenseAsync(string licenseFilePath)` 方法
  - 定义返回类型 `LicenseCheckResult`
- [x] 3.2 实现 StaticAuthChecker 服务
  - 创建 `MaterialClient.Common/Services/StaticLicenseChecker.cs`
  - **TODO**：当前实现默认返回成功，不进行实际授权验证
  - 记录授权结果到日志（Debug 模式显示状态）
  - 标记为 `ISingletonDependency` + `[AutoConstructor]`
  - 为后续实际授权逻辑预留接口
- [x] 3.3 集成静态授权到 Urban 启动流程
  - 修改 `MaterialClient.Urban/App.axaml.cs`
  - 在 `OnApplicationInitialization` 中调用授权检查
  - 授权失败不阻止应用启动（仅记录日志）

## 4. 主窗口 UI 实现

- [x] 4.1 迁移主窗口布局
  - 从 `MaterialClient.Demo/Views/WeighingSystemWindow.axaml` 复制布局
  - 创建 `MaterialClient.Urban/Views/WeighingSystemWindow.axaml`
  - 调整窗口标题为"凡东城管地磅系统"
  - 配置窗口大小 1280×800，最小 900×600
- [x] 4.2 精简顶栏菜单
  - 修改顶栏菜单布局
  - 保留"系统设置"按钮（启用）
  - 移除"退出登录"按钮
  - 首期隐藏"数据同步"、"项目信息"按钮
- [x] 4.3 创建 WeighingSystemViewModel
  - 创建 `MaterialClient.Urban/ViewModels/WeighingSystemViewModel.cs`
  - 继承 `ReactiveObject` 或 `ViewModelBase`
  - 实现称重记录列表绑定
  - 实现照片显示功能
  - 实现设备状态监控
- [x] 4.4 实现设备状态栏
  - 创建设备状态数据模型（`DeviceStatus`）
  - 实现设备状态实时更新逻辑
  - 使用颜色指示器（绿色/红色）显示在线/离线状态
- [x] 4.5 实现照片显示区域
  - 创建照片区域布局（车牌识别抓拍、摄像头抓拍）
  - 实现照片加载逻辑（优先本地缓存，其次服务器）
  - 实现照片加载失败占位显示
  - 显示照片拍摄时间

## 5. 样式与资源管理

- [x] 5.1 抽取全局样式到 App.axaml
  - 从 `WeighingSystemWindow.axaml` 复制样式定义
  - 移动到 `App.axaml` 的 `Resources` 节点
  - 包含样式：`tab-btn`、`search-btn`、`reset-btn`、DataGrid 等
- [x] 5.2 验证样式一致性
  - 确保 Urban 主界面样式与 Demo 一致
  - 验证颜色方案（#0F172A 背景、#4169E1 主色）
  - 验证字体和间距

## 6. 测试与验证

- [x] 6.1 创建单元测试：StaticAuthChecker
  - 测试授权成功场景
  - 测试授权失败场景
  - 测试日志记录功能
- [x] 6.2 创建 UI 测试：Urban 应用启动
  - 测试应用启动直接进入主界面
  - 测试无登录窗口显示
  - 测试静态授权后台执行
  - 测试设备状态栏显示
- [x] 6.3 性能测试
  - 测试应用启动时间 < 3 秒
  - 测试内存占用（空闲 < 200MB）
- [x] 6.4 资源泄漏测试
  - 测试应用退出无资源泄漏
  - 测试内存正确释放

## 7. 文档与交付

- [ ] 7.1 创建 Urban 部署指南
  - 编写 `docs/urban-deployment-guide.md`
  - 说明 Urban 应用安装步骤
  - 说明配置文件修改方法
- [ ] 7.2 创建 Urban 用户手册
  - 编写 `docs/urban-user-manual.md`
  - 说明主界面功能
  - 说明设备状态指示器含义
- [x] 7.3 更新 AGENTS.md
  - 记录 Urban 项目特殊约定
  - 记录静态授权实现细节

## 8. 发布准备

- [ ] 8.1 配置 Urban 项目编译
  - 验证 Release 编译配置
  - 验证 x64 单文件发布
- [ ] 8.2 创建 Urban 安装程序
  - 配置 Installer 项目（如使用）
  - 包含 Urban 可执行文件
  - 配置快捷方式和文件关联
- [ ] 8.3 准备灰度发布
  - 选择 1-2 个试点站点
  - 准备回滚方案（保留原 MaterialClient）
  - 配置监控指标（启动时间、崩溃率）
- [ ] 8.4 执行灰度发布
  - 部署到试点站点
  - 监控运行状态
  - 收集用户反馈
  - 根据反馈调整配置
