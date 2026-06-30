## MODIFIED Requirements

### Requirement: 离线 license.urban 引导保留

在线激活能力 SHALL 为主路径；`license.urban` bootstrap 代码路径 SHALL 保留（启动时仍尝试读取，`SystemSettings.LicenseFilePath` 默认仍为 `license.urban`），但**离线授权文件导入 UI 入口 SHALL 被移除**（V2 收敛为纯在线验证）。用户面向的授权流程 SHALL 仅通过在线激活完成；离线路径仅作为无 UI 的代码层应急/防回退。

#### Scenario: 离线 bootstrap 代码保留但无 UI 入口

- **WHEN** 应用启动且本地无 `LatestJwtToken`
- **THEN** 启动序列 SHALL 仍尝试读取 `license.urban`（代码路径保留）
- **AND** 当 `license.urban` 含有效 BasePlatform JWT 时 SHALL 通过门禁并回写 `LatestJwtToken`
- **AND** MUST NOT 在未授权窗或设置页提供离线文件导入按钮 / 路径选择 UI

#### Scenario: 设置页移除离线授权 UI 区域

- **WHEN** 用户进入设置页
- **THEN** 「离线授权」相关 UI 区域（导出/导入按钮、文件路径选择、离线导入对话框）SHALL 被移除
- **AND** MUST NOT 暴露引导用户走离线流程的提示文案

### Requirement: Urban 专用授权 UI

MaterialClient.Urban 授权对话框 SHALL 仅提供在线激活（接入码输入 + 本机 `MachineCode` 展示/复制 + 在线激活按钮）。离线授权导入相关控件 SHALL 被移除；`UrbanActivationUiOptions.ShowOfflineActivationUi` 开关 SHALL 移除（彻底裁剪，非软隐藏）。

#### Scenario: 未授权窗仅含在线激活

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权窗 / 授权对话框 SHALL 仅展示在线激活入口
- **AND** MUST NOT 展示离线授权机器码复制用于离线导入的区域
- **AND** 离线 UI 相关 XAML 与 `ShowOfflineActivationUi` 开关 SHALL 被删除
