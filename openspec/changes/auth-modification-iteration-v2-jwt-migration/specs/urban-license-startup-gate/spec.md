## MODIFIED Requirements

### Requirement: Unauthorized notice dialog

When startup authorization is invalid, MaterialClient.Urban SHALL display a modal notice before exit. The notice SHALL present **only the online activation entry**（输入接入码 → 在线激活）；离线 `license.urban` 文件导入入口 SHALL 被移除（V2 收敛为纯在线验证）。`license.urban` bootstrap 代码路径 SHALL 保留（应急/防回退），但 MUST NOT 在未授权窗暴露导入 UI。The notice MAY include the technical failure message from `LicenseCheckResult.Message` as secondary detail.

#### Scenario: 仅展示在线激活入口

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权窗 SHALL 展示「在线激活」入口（接入码输入 + 本机机器码展示/复制）
- **AND** MUST NOT 展示离线授权文件导入按钮或路径选择
- **AND** MUST NOT 出现「请导入离线授权文件」类引导文案

#### Scenario: 在线激活成功后继续启动

- **WHEN** 用户在未授权窗在线激活成功（`ActivateAsync` 写入 `LatestJwtToken`）
- **THEN** SHALL 关闭未授权窗并继续启动称重主界面
- **AND** SHALL NOT 要求重启（或按现有激活流程收敛）

#### Scenario: 用户取消未授权窗退出应用

- **WHEN** 用户关闭/取消未授权窗（未完成在线激活）
- **THEN** SHALL 调用应用关闭
- **AND** SHALL NOT 启动 SignalR、轮询上传、称重设备服务

## ADDED Requirements

### Requirement: 启动门禁的在线-only 失败分支

启动时 `LatestJwtToken` 无值或本地验签失败时，SHALL 直接进入仅含在线激活的未授权窗，MUST NOT 提供离线导入分支。`license.urban` bootstrap 仅在代码层于启动序列中尝试读取（无 UI 交互）。

#### Scenario: 无 LatestJwtToken 进入在线激活窗

- **WHEN** `LicenseInfo.LatestJwtToken` 为空或无效，且 `license.urban` 未提供有效 JWT
- **THEN** SHALL 弹出仅在线激活的未授权窗
- **AND** MUST NOT 弹出离线文件导入对话框
