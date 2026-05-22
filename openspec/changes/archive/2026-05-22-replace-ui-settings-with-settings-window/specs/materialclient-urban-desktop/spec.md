## MODIFIED Requirements

### Requirement: 顶栏菜单精简

MaterialClient.Urban 顶栏菜单 MUST 仅包含"系统设置"入口，MUST NOT 包含"退出登录"等与登录相关的菜单项。"系统设置"按钮 MUST 打开 MaterialClient.UI 提供的共享 `SettingsWindow`（与 MaterialClient 主程序相同的完整设置界面）。

#### Scenario: 顶栏菜单显示
- **WHEN** 用户查看顶栏菜单
- **THEN** SHALL 显示"系统设置"按钮（启用）
- **AND** SHALL NOT 显示"退出登录"按钮
- **AND** SHALL NOT 显示"数据同步"按钮（首期）
- **AND** SHALL NOT 显示"项目信息"按钮（首期）

#### Scenario: 系统设置入口
- **WHEN** 用户点击"系统设置"按钮
- **THEN** SHALL 打开 MaterialClient.UI 的 `SettingsWindow` 窗口
- **AND** `SettingsWindow` SHALL 显示与 main 分支一致的七个设置分区（地磅、称重、摄像头、车牌识别、系统、音响、打印机）
- **AND** SHALL 允许修改系统配置并保存到本地设置存储
- **AND** MUST NOT 打开 `SettingsDialog` 或依赖 `ISettingsSection` 自动发现
