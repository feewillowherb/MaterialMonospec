## MODIFIED Requirements

### Requirement: 顶栏菜单精简

MaterialClient.Urban 顶栏菜单 MUST 仅包含"系统设置"入口，MUST NOT 包含"退出登录"等与登录相关的菜单项。"系统设置"按钮 MUST 打开 MaterialClient.UI 提供的共享 SettingsDialog。

#### Scenario: 顶栏菜单显示
- **WHEN** 用户查看顶栏菜单
- **THEN** SHALL 显示"系统设置"按钮（启用）
- **AND** SHALL NOT 显示"退出登录"按钮
- **AND** SHALL NOT 显示"数据同步"按钮（首期）
- **AND** SHALL NOT 显示"项目信息"按钮（首期）

#### Scenario: 系统设置入口
- **WHEN** 用户点击"系统设置"按钮
- **THEN** SHALL 打开 MaterialClient.UI 的 SettingsDialog 窗口
- **AND** SettingsDialog SHALL 自动发现并显示 Urban 注册的 ISettingsSection 实现
- **AND** SHALL 允许修改系统配置并保存

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 采用四行三列布局。设备状态栏（Row 3）MUST 使用 MaterialClient.UI 的 DeviceStatusBar 共享控件替代内联实现。使用 MaterialClient 共享样式类替代内联样式。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示标题栏（Row 0, Auto height, #4169E1 背景）
- **AND** SHALL 显示重量区（Row 1, Auto height, #4A85F9 渐变背景）
- **AND** SHALL 显示三列内容区（Row 2, *）：
  - Col 0 (280px): 称重记录列表 + 筛选 + 分页
  - Col 1 (*): 主内容区
  - Col 2 (360px): 照片显示区
- **AND** SHALL 显示 MaterialClient.UI DeviceStatusBar 控件（Row 3, Auto height）

#### Scenario: 重量区显示真实称重数据
- **WHEN** 称重管线正在运行
- **THEN** 重量区 SHALL 显示 CurrentWeight（由 ViewModel 绑定驱动）
- **AND** SHALL 显示 WeightStatus 文案和对应颜色
- **AND** SHALL NOT 显示 mock 数据

#### Scenario: 窗口配置
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上
- **AND** SHALL 使用 `SystemDecorations="None"`（与 MaterialClient 一致）
- **AND** SHALL 设置窗口 Icon（`/Assets/fd-ico.ico`）

### Requirement: 设备状态栏实时更新

MaterialClient.Urban 设备状态栏 MUST 使用 MaterialClient.UI 的 DeviceStatusBar 共享控件实时显示设备在线状态，MUST NOT 使用内联状态栏实现。

#### Scenario: 设备状态显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 使用 `<ui:DeviceStatusBar>` 控件显示设备状态
- **AND** SHALL 绑定到共享 DeviceStatusBarViewModel
- **AND** SHALL 显示地磅设备状态（● 在线/离线）
- **AND** SHALL 显示所有摄像头状态（● 在线/离线）
- **AND** SHALL 显示车牌识别设备状态（● 在线/离线）

#### Scenario: 设备状态更新
- **WHEN** 设备状态发生变化
- **THEN** SHALL 通过 ILocalEventBus 事件驱动更新
- **AND** SHALL 在 1 秒内更新状态栏显示
- **AND** 在线设备 SHALL 显示绿色指示器
- **AND** 离线设备 SHALL 显示红色指示器

### Requirement: 样式复用与隔离

MaterialClient.Urban MUST 通过导入 MaterialClient.UI 的 SharedTheme.axaml 获取共享样式类和颜色资源，MUST NOT 定义与 SharedTheme 重复的样式。

#### Scenario: 全局样式定义
- **WHEN** App.axaml 加载
- **THEN** SHALL 导入 MaterialClient.UI 的 SharedTheme.axaml 作为合并资源字典
- **AND** SHALL 使用 SharedTheme 中的 primary-button、titlebar-close-button 等样式类
- **AND** SHALL 使用 SharedTheme 中的命名颜色画刷
- **AND** MUST NOT 重复定义 SharedTheme 中已有的颜色资源

#### Scenario: 样式一致性
- **WHEN** 用户查看主界面
- **THEN** 标题栏 SHALL 使用 SharedTheme 命名颜色资源
- **AND** 按钮 SHALL 使用 SharedTheme 共享样式类
- **AND** MUST NOT 使用硬编码色值
