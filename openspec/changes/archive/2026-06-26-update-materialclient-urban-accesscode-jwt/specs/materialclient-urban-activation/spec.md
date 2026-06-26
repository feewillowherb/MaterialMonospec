## ADDED Requirements

### Requirement: Urban 在线激活 API

`MaterialClient.Urban` SHALL 通过 Refit 接口 `IUrbanAuthApi` 调用 UrbanManagement 代理端点 `POST /api/urban/auth/activate`，请求体包含 `ProductCode = 5001`、`Code`（接入码）、`MachineCode`（本机机器码）。MUST NOT 在请求中传递 `ProId`。

#### Scenario: Refit 端点定义

- **WHEN** 查看 `IUrbanAuthApi`
- **THEN** SHALL 存在 `[Post("/api/urban/auth/activate")]` 方法
- **AND** 请求类型 SHALL 包含 `ProductCode`、`Code`、`MachineCode`

#### Scenario: 激活成功响应

- **WHEN** Urban 返回 HTTP 成功且 body 含 `jwtToken`
- **THEN** `ActivateAsync` SHALL 使用 `jwtToken` 调用 `CheckLicenseFromTokenAsync`
- **AND** 验签通过后 SHALL 持久化 `LicenseInfo`（含 `LatestJwtToken`、`AccessCode` 等）

#### Scenario: 禁止直连 BasePlatform

- **WHEN** ProductCode 为 Urban（5001/5030 上下文下的城管激活）
- **THEN** MUST NOT 调用 `VerifyAuthorizationCodeAsync` 直连 BasePlatform
- **AND** SHALL 仅通过 `activate` 代理激活

### Requirement: ActivateAsync 服务方法

`ILicenseService` SHALL 提供 `ActivateAsync` 方法：调用 Urban API → 本地 JWT 验签（含 `machineCode`）→ Insert/Update `LicenseInfo`。写操作 SHALL 使用 `[UnitOfWork]`。

#### Scenario: 成功激活持久化

- **WHEN** `ActivateAsync` 完成且 JWT 验签通过
- **THEN** SHALL 写入或更新 `LicenseInfo.LatestJwtToken`
- **AND** SHALL 从 JWT claims 写入 `ProjectId`、`ProName`、`AccessCode`、`AuthEndTime`、`MachineCode`
- **AND** MUST NOT 写入 `AuthToken` 或 `FdBuildLicenseNo`

#### Scenario: 激活失败不修改 LicenseInfo

- **WHEN** Urban API 失败或 JWT 验签失败
- **THEN** SHALL NOT 修改现有 `LicenseInfo` 记录
- **AND** SHALL 向调用方返回失败原因

### Requirement: Urban 专用授权 UI

MaterialClient.Urban SHALL 提供专用授权对话框，供用户输入接入码并触发在线激活。对话框 SHALL 展示本机 `MachineCode`（只读或可拷贝）。5001 产品 MUST NOT 复用主程序 `AuthCodeWindow` 或登录流。

#### Scenario: 用户在线激活

- **WHEN** 用户在授权对话框输入有效接入码并确认激活
- **THEN** SHALL 调用 `ActivateAsync` 且 `MachineCode` 为本机值
- **AND** 成功时 SHALL 关闭对话框并允许应用继续启动或刷新授权状态

#### Scenario: 未授权时提供激活入口

- **WHEN** 启动门禁判定未授权
- **THEN** 未授权提示或关联 UI MAY 提供「在线激活」入口打开授权对话框
- **AND** MUST NOT 要求用户登录 MaterialClient 主账号

### Requirement: 离线 license.urban 引导保留

在线激活能力 SHALL 与现有 `license.urban` 离线 bootstrap 共存。`SystemSettings.LicenseFilePath` 默认仍为 `license.urban`。

#### Scenario: 离线文件仍有效

- **WHEN** 用户部署有效 `license.urban` 且 JWT 满足 BasePlatform 验签规则
- **THEN** 启动 SHALL 无需在线激活即可通过门禁
- **AND** bootstrap 成功后 SHALL 回写 `LatestJwtToken`（见 `urban-license-startup-gate` delta）
