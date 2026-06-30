## MODIFIED Requirements

### Requirement: Unauthorized notice dialog

When startup authorization is invalid, MaterialClient.Urban SHALL display a modal notice before exit. The notice SHALL present **only the online activation entry**（输入接入码 → 在线激活）；离线 `license.urban` 文件导入入口 SHALL 被移除（V2 收敛为纯在线验证）。`license.urban` bootstrap 代码路径 SHALL 保留（应急/防回退），但 MUST NOT 在未授权窗暴露导入 UI。The notice MAY include the technical failure message from `LicenseCheckResult.Message` as secondary detail.

#### Scenario: 仅展示在线激活入口

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权窗 SHALL 展示「在线激活」入口（接入码输入 + 本机机器码展示/复制）
- **AND** MUST NOT 展示离线授权文件导入按钮或路径选择
- **AND** MUST NOT 出现「请导入离线授权文件」类引导文案

#### Scenario: 在线激活成功后重启进程

- **WHEN** 用户在未授权窗在线激活成功（`ActivateUrbanAsync` 写入 `LatestJwtToken`）
- **THEN** SHALL 关闭未授权窗并请求重启整个应用进程（见 `urban-activation-process-restart`）
- **AND** MUST NOT 在同进程继续启动称重主界面或后台服务
- **AND** 新进程冷启动通过后 SHALL 打开 `UrbanAttendedWeighingWindow` 并完成完整初始化（含 SignalR）

#### Scenario: 用户取消未授权窗退出应用

- **WHEN** 用户关闭/取消未授权窗（未完成在线激活）
- **THEN** SHALL 调用应用关闭
- **AND** SHALL NOT 启动 SignalR、轮询上传、称重设备服务
- **AND** SHALL NOT 启动新进程
