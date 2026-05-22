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
- **AND** SettingsDialog SHALL 显示与主应用相同的 7 个设置分区（地磅、称重、摄像头、车牌、系统、音频、打印机）
- **AND** SHALL 允许修改系统配置并保存，持久化行为与主应用一致

### Requirement: 设备状态栏实时更新

MaterialClient.Urban 设备状态栏 MUST 使用 MaterialClient.UI 的 DeviceStatusBar 共享控件实时显示设备在线状态，MUST NOT 使用内联状态栏实现。设备集合 MUST 与主应用完全一致。

#### Scenario: 设备状态显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 使用 `<ui:DeviceStatusBar>` 控件显示设备状态
- **AND** SHALL 绑定到共享 DeviceStatusBarViewModel
- **AND** SHALL 显示地磅设备状态（● 在线/离线）
- **AND** SHALL 显示所有摄像头状态（● 在线/离线）
- **AND** SHALL 显示 USB 摄像头状态（● 在线/离线）
- **AND** SHALL 显示打印机状态（● 在线/离线）
- **AND** SHALL 显示音频设备状态（● 在线/离线）
- **AND** SHALL 显示车牌识别设备状态（● 在线/离线）

#### Scenario: 设备状态更新
- **WHEN** 设备状态发生变化
- **THEN** SHALL 通过 ILocalEventBus 事件驱动更新
- **AND** SHALL 在 1 秒内更新状态栏显示
- **AND** 在线设备 SHALL 显示绿色指示器
- **AND** 离线设备 SHALL 显示红色指示器
