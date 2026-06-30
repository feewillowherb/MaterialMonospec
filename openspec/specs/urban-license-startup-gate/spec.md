# Urban License Startup Gate Specification

## Purpose

定义 MaterialClient.Urban 启动时 JWT 授权门禁：无有效 `ProId` 时阻塞进入称重主界面，并向用户展示未授权提示。
## Requirements
### Requirement: Startup blocks when authorization is invalid

MaterialClient.Urban SHALL evaluate authorization during ABP application initialization before presenting the weighing main window. Authorization SHALL be considered valid only when startup JWT validation succeeds via `IStaticLicenseChecker` (**BasePlatform issuer**, `accessCode` and `machineCode` claims) and yields a non-empty `ProId` in `LicenseCheckResult`. When authorization is invalid, the application MUST NOT open `UrbanAttendedWeighingWindow`, MUST NOT start the attended weighing pipeline or hardware device manager, and MUST exit after the user dismisses the unauthorized notice.

#### Scenario: Valid JWT with ProId allows startup

- **WHEN** startup JWT validation succeeds from `LatestJwtToken` or `license.urban`
- **AND** `LicenseCheckResult.ProId` is a non-empty GUID
- **THEN** SHALL write or update `LicenseInfo` including `AccessCode` and `LatestJwtToken` when bootstrapped from file
- **AND** SHALL open `UrbanAttendedWeighingWindow` and continue the normal startup sequence

#### Scenario: Missing license file and no LatestJwtToken blocks startup

- **WHEN** `LicenseInfo.LatestJwtToken` is null or empty
- **AND** the configured license file (default `license.urban`) does not exist or is invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT open the weighing main window
- **AND** SHALL show the unauthorized notice to the user
- **AND** SHALL exit the application after the user confirms the notice

#### Scenario: JWT validation failure blocks startup

- **WHEN** JWT signature validation fails, the token is expired, `iss` is not `BasePlatform`, `machineCode` mismatches, `accessCode` is missing, or `proId` claim is missing or invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT write or update `LicenseInfo`
- **AND** SHALL show the unauthorized notice and exit as above

#### Scenario: All build configurations enforce the gate

- **WHEN** startup authorization is invalid
- **THEN** invalid startup authorization MUST block the main window in both Debug and Release builds
- **AND** MUST NOT provide a configuration flag or compile-time bypass

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

### Requirement: Startup authorization result exposed to App layer

The authorization outcome from `MaterialClientUrbanModule` initialization SHALL be available to `App.axaml.cs` through an injectable service or equivalent ABP-registered singleton so the UI layer can branch without duplicating JWT validation logic.

#### Scenario: App reads module authorization result

- **WHEN** `AbpApplication.InitializeAsync` completes
- **THEN** `App.axaml.cs` SHALL read whether startup authorization succeeded
- **AND** SHALL branch to main window or unauthorized notice based on that result only

### Requirement: Bootstrap from license.urban writes LatestJwtToken

When startup authorization succeeds by reading `license.urban` (because `LatestJwtToken` was empty or invalid), the module SHALL persist the JWT text to `LicenseInfo.LatestJwtToken` so subsequent starts and SignalR sync use the same authoritative token.

#### Scenario: First bootstrap from file

- **WHEN** `LatestJwtToken` is empty and `license.urban` contains a valid BasePlatform JWT
- **THEN** startup SHALL succeed
- **AND** SHALL write the file JWT content to `LicenseInfo.LatestJwtToken`
- **AND** SHALL persist `AccessCode` and other claims to `LicenseInfo`

#### Scenario: Subsequent start uses LatestJwtToken

- **WHEN** `LicenseInfo.LatestJwtToken` is populated from a prior bootstrap
- **THEN** startup SHALL prefer `LatestJwtToken` over re-reading the file
- **AND** SHALL NOT require `license.urban` to exist if `LatestJwtToken` is valid

### Requirement: 启动门禁的在线-only 失败分支

启动时 `LatestJwtToken` 无值或本地验签失败时，SHALL 直接进入仅含在线激活的未授权窗，MUST NOT 提供离线导入分支。`license.urban` bootstrap 仅在代码层于启动序列中尝试读取（无 UI 交互）。

#### Scenario: 无 LatestJwtToken 进入在线激活窗

- **WHEN** `LicenseInfo.LatestJwtToken` 为空或无效，且 `license.urban` 未提供有效 JWT
- **THEN** SHALL 弹出仅在线激活的未授权窗
- **AND** MUST NOT 弹出离线文件导入对话框

