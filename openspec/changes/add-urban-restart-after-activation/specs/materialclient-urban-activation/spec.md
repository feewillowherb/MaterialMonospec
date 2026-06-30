## MODIFIED Requirements

### Requirement: Urban 专用授权 UI

MaterialClient.Urban 授权对话框 SHALL 仅提供在线激活（接入码输入 + 本机 `MachineCode` 展示/复制 + 在线激活按钮）。离线授权导入相关控件 SHALL 被移除；`UrbanActivationUiOptions.ShowOfflineActivationUi` 开关 SHALL 移除（彻底裁剪，非软隐藏）。

#### Scenario: 未授权窗仅含在线激活

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权窗 / 授权对话框 SHALL 仅展示在线激活入口
- **AND** MUST NOT 展示离线授权机器码复制用于离线导入的区域
- **AND** 离线 UI 相关 XAML 与 `ShowOfflineActivationUi` 开关 SHALL 被删除

#### Scenario: 用户在线激活

- **WHEN** 用户在授权对话框输入有效接入码并确认激活
- **THEN** SHALL 调用 `ActivateUrbanAsync` 且 `MachineCode` 为本机值
- **AND** 成功时 SHALL 关闭对话框并请求重启应用进程（见 `urban-activation-process-restart`）
- **AND** MUST NOT 在同进程仅刷新授权状态后继续业务

#### Scenario: 未授权时提供激活入口

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权提示或关联 UI MAY 提供「在线激活」入口打开授权对话框
- **AND** MUST NOT 要求用户登录 MaterialClient 主账号
