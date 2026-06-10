# MaterialClient Urban Desktop Specification

## Purpose

定义 MaterialClient Urban 桌面应用的功能需求，包括单窗口称重主界面、静态授权检查、以及与 MaterialClient 主应用的架构差异。

## ADDED Requirements

### Requirement: Urban 应用启动进入唯一主界面

MaterialClient.Urban 应用启动时 MUST 直接显示称重主界面（WeighingSystemWindow），MUST NOT 显示登录窗口或授权窗口。

#### Scenario: 正常启动流程
- **WHEN** 用户启动 MaterialClient.Urban 应用
- **THEN** SHALL 直接显示称重主界面（1280×800）
- **AND** SHALL NOT 显示登录窗口
- **AND** SHALL NOT 显示授权窗口
- **AND** SHALL 记录授权检查结果到日志（Debug 模式）

#### Scenario: 启动失败处理（TODO：默认成功，此场景暂不触发）
- **WHEN** 静态授权检查失败（TODO：当前实现默认返回成功，此场景不会触发）
- **THEN** SHALL 记录错误日志
- **AND** SHALL 继续启动应用（不阻止用户使用）

### Requirement: Urban 配置模式

MaterialClient.Urban MUST 使用 UrbanMode = 201 和 ProductCode = 5030，MUST NOT 支持其他 WeighingMode。

#### Scenario: Urban 模式识别
- **WHEN** 应用查询当前 WeighingMode
- **THEN** SHALL 返回 UrbanMode (201)
- **AND** SHALL 返回 ProductCode 为 5030

#### Scenario: 标题栏显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示"凡东城管地磅系统"标题
- **AND** SHALL 显示"城管固废称重验收系统客户端软件"描述

### Requirement: 顶栏菜单精简

MaterialClient.Urban 顶栏菜单 MUST 仅包含"系统设置"入口，MUST NOT 包含"退出登录"等与登录相关的菜单项。

#### Scenario: 顶栏菜单显示
- **WHEN** 用户查看顶栏菜单
- **THEN** SHALL 显示"系统设置"按钮（启用）
- **AND** SHALL NOT 显示"退出登录"按钮
- **AND** SHALL NOT 显示"数据同步"按钮（首期）
- **AND** SHALL NOT 显示"项目信息"按钮（首期）

#### Scenario: 系统设置入口
- **WHEN** 用户点击"系统设置"按钮
- **THEN** SHALL 打开设置窗口
- **AND** SHALL 允许修改系统配置

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在应用启动时执行静态授权检查（IStaticLicenseChecker），MUST NOT 向 UI 暴露授权状态。

**TODO**：当前实现默认返回成功，不进行实际授权验证，后续完善实际授权逻辑。

#### Scenario: 后台授权检查（TODO：默认成功）
- **WHEN** 应用启动
- **THEN** SHALL 在 OnApplicationInitialization 中调用 StaticAuthChecker
- **AND** SHALL 读取 LicenseFilePath 配置
- **AND** SHALL 默认返回成功（TODO：后续实现实际授权逻辑）
- **AND** SHALL 记录检查结果到日志
- **AND** MUST NOT 显示授权对话框

#### Scenario: Debug 模式状态显示
- **WHEN** 应用在 Debug 模式下运行
- **THEN** SHALL 在设备状态栏显示授权状态文本
- **AND** SHALL 使用绿色（成功）或红色（失败）指示器

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 采用四行布局：标题栏 / 重量区 / 列表+照片侧栏 / 设备状态栏。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示标题栏（高度 48px，包含logo、标题、最小化、关闭按钮）
- **AND** SHALL 显示重量区（高度 72px，包含重量显示和状态文本）
- **AND** SHALL 显示列表+照片侧栏（剩余空间，左侧记录列表、右侧照片显示）
- **AND** SHALL 显示设备状态栏（高度 36px，显示设备在线状态）

#### Scenario: 窗口尺寸
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上

### Requirement: 照片显示区域

MaterialClient.Urban 右侧照片区 MUST 显示两张照片：车牌识别抓拍和摄像头抓拍，MUST 支持从本地缓存或服务器加载。

#### Scenario: 照片区域布局
- **WHEN** 用户查看称重记录详情
- **THEN** SHALL 显示"车牌识别抓拍"照片区域（高度 120px）
- **AND** SHALL 显示"摄像头抓拍"照片区域（高度 120px）
- **AND** SHALL 显示照片拍摄时间

#### Scenario: 照片加载逻辑
- **WHEN** 用户选择一条称重记录
- **THEN** SHALL 优先从本地缓存加载照片
- **AND** 如果本地缓存不存在，SHALL 从服务器加载照片
- **AND** SHALL 将下载的照片保存到本地缓存

#### Scenario: 照片加载失败
- **WHEN** 照片加载失败（本地和服务器均无）
- **THEN** SHALL 显示占位图标（🚛）
- **AND** SHALL 显示灰色背景

### Requirement: 设备状态栏实时更新

MaterialClient.Urban 设备状态栏 MUST 实时显示地磅设备、摄像头、车牌识别设备的在线状态，使用颜色指示器。

#### Scenario: 设备状态显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示地磅设备状态（● 在线/离线）
- **AND** SHALL 显示所有摄像头状态（● 在线/离线）
- **AND** SHALL 显示车牌识别设备状态（● 在线/离线）

#### Scenario: 设备状态更新
- **WHEN** 设备状态发生变化
- **THEN** SHALL 在 1 秒内更新状态栏显示
- **AND** 在线设备 SHALL 显示绿色指示器
- **AND** 离线设备 SHALL 显示红色指示器
- **AND** SHALL 记录状态变化到日志

### Requirement: 无 Generic Host 交付形态

MaterialClient.Urban MUST NOT 使用 Generic Host 作为交付形态，MUST 使用 Avalonia ApplicationLifetime。

#### Scenario: 应用生命周期
- **WHEN** 应用启动
- **THEN** SHALL 使用 Avalonia 的 ApplicationLifetime
- **AND** MUST NOT 注册 Generic Host
- **AND** MUST NOT 注册主 MaterialClient 的登录/Session 模块

#### Scenario: 应用退出
- **WHEN** 用户关闭应用窗口
- **THEN** SHALL 正确清理应用资源
- **AND** SHALL 保存应用状态

### Requirement: 样式复用与隔离

MaterialClient.Urban MUST 复用 Demo 中的样式定义（tab-btn、search-btn、DataGrid 等），MUST 抽取到 App.axaml Resources 中。

#### Scenario: 全局样式定义
- **WHEN** App.axaml 加载
- **THEN** SHALL 在 App.axaml.Resources 中定义全局样式
- **AND** SHALL 包含 tab-btn 样式（标签按钮）
- **AND** SHALL 包含 search-btn 样式（搜索按钮）
- **AND** SHALL 包含 DataGrid 样式（数据表格）

#### Scenario: 样式一致性
- **WHEN** 用户查看主界面
- **THEN** SHALL 按钮样式与 Demo 一致
- **AND** SHALL DataGrid 样式与 Demo 一致
- **AND** SHALL 颜色方案与 Demo 一致（#0F172A 背景、#4169E1 主色）

### Requirement: Lrp 附件类型保存

MaterialClient.Urban MUST 在 UrbanMode = 201 时保存车牌识别图片为 Lrp 类型附件，MUST NOT 在其他模式保存 Lrp 附件。Lrp 图片 MUST 经过压缩处理。

#### Scenario: Urban 模式保存 Lrp 附件
- **WHEN** UrbanMode = 201 且车牌识别成功
- **THEN** SHALL 保存车牌识别图片为 Lrp 类型附件
- **AND** SHALL 使用 `JpegCompressionUtil.TryCompressJpegBytes` 压缩图片
- **AND** SHALL 压缩质量保持车牌识别清晰度
- **AND** SHALL 在 Attachment 表中记录 AttachType = Lrp

#### Scenario: 非Urban 模式不保存 Lrp 附件
- **WHEN** WeighingMode != UrbanMode (201)
- **THEN** MUST NOT 保存 Lrp 类型附件
- **AND** SHALL 使用现有附件类型（Photo 等）

#### Scenario: Hikvision Lrp 附件保存
- **WHEN** HikvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 保存识别结果图片为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 记录附件元数据（识别时间、车牌号、设备信息）

#### Scenario: Vzvision Lrp 附件保存
- **WHEN** VzvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 保存识别结果图片为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 记录附件元数据（识别时间、车牌号、设备信息）

#### Scenario: Lrp 图片压缩质量
- **WHEN** 压缩 Lrp 图片
- **THEN** SHALL 使用适当的 JPEG 质量（85-95%）
- **AND** SHALL 确保车牌号码仍然清晰可识别
- **AND** SHALL 减少文件大小至少 30%
