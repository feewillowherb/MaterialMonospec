## ADDED Requirements

### Requirement: Urban 顶部菜单栏"项目信息"按钮

MaterialClient.Urban 的 `UrbanAttendedWeighingWindow` 顶部菜单栏 SHALL 在"系统设置"按钮旁提供"项目信息"按钮。

#### Scenario: 按钮显示位置

- **WHEN** `UrbanAttendedWeighingWindow` 渲染 `WeighingWindowBase.MenuItems` 区域
- **THEN** MUST 在"系统设置"按钮前方（左侧）显示"项目信息"按钮
- **AND** 按钮样式 MUST 与"系统设置"按钮一致（使用 `popup-menu-item-button` class）

#### Scenario: 按钮点击打开项目信息窗口

- **WHEN** 用户点击"项目信息"按钮
- **THEN** 系统 SHALL 通过 DI 容器解析 `ProjectInfoWindow`
- **AND** SHALL 调用 `ProjectInfoWindowViewModel.InitializeAsync()` 加载数据
- **AND** SHALL 以 `ShowDialog(parentWindow)` 方式打开窗口
- **AND** MUST NOT 抛出未处理异常

#### Scenario: 窗口打开失败降级

- **WHEN** 打开项目信息窗口过程中发生异常（如服务不可达）
- **THEN** 系统 SHALL NOT 崩溃
- **AND** SHALL 记录错误日志

---

### Requirement: ProjectInfoWindow 从 MaterialClient.UI 共享层打开

Urban SHALL 通过 DI 解析 `MaterialClient.UI.Views.ProjectInfoWindow`，MUST NOT 直接引用主项目 `MaterialClient.Views.ProjectInfoWindow`。

#### Scenario: DI 解析共享窗口

- **WHEN** Urban 通过 `_serviceProvider.GetRequiredService<ProjectInfoWindow>()` 解析窗口
- **THEN** MUST 返回 `MaterialClient.UI.Views.ProjectInfoWindow` 实例
- **AND** ViewModel MUST 为 `MaterialClient.UI.ViewModels.ProjectInfoWindowViewModel`

#### Scenario: 主项目与 Urban 使用同一实现

- **WHEN** 主项目和 Urban 各自打开"项目信息"窗口
- **THEN** 两者 MUST 使用 MaterialClient.UI 中的同一个 `ProjectInfoWindow` 和 `ProjectInfoWindowViewModel` 实现
- **AND** 窗口布局、样式、行为 MUST 完全一致

---

### Requirement: ProjectInfoWindow 展示授权信息字段

`ProjectInfoWindowViewModel` SHALL 通过 `IAuthenticationService`、`ILicenseService`、`ISettingsService` 加载并展示以下字段。

#### Scenario: 项目名称

- **WHEN** `InitializeAsync()` 被调用
- **AND** `IAuthenticationService.GetCurrentSessionAsync()` 返回有效 `UserSession`
- **THEN** `ProjectName` MUST 显示 `UserSession.CompanyName`

#### Scenario: 产品名称

- **WHEN** `InitializeAsync()` 被调用
- **AND** `ISettingsService.GetSettingsAsync()` 返回有效 `SettingsEntity`
- **THEN** `ProductNameDisplay` MUST 显示对应产品模式名称

#### Scenario: 到期时间

- **WHEN** `InitializeAsync()` 被调用
- **AND** `ILicenseService.GetCurrentLicenseAsync()` 返回有效 `LicenseInfo`
- **THEN** `ExpirationDate` MUST 显示 `LicenseInfo.AuthEndTime`，格式为 `yyyy-MM-dd`
- **AND** 到期时间文本颜色 MUST 为红色（`#DC3545`）

#### Scenario: 机器码

- **WHEN** `InitializeAsync()` 被调用
- **AND** `LicenseInfo.MachineCode` 不为空
- **THEN** `MachineCode` MUST 显示遮掩后的机器码（前 4 位 + `****` + 后 4 位）

#### Scenario: 机器码为空

- **WHEN** `InitializeAsync()` 被调用
- **AND** `LicenseInfo.MachineCode` 为 null 或空字符串
- **THEN** `MachineCode` MUST 显示空文本
- **AND** 机器码标签行 MUST 仍可见

#### Scenario: 授权码

- **WHEN** `InitializeAsync()` 被调用
- **AND** `LicenseInfo.AuthToken` 不为空
- **THEN** `AuthCode` MUST 显示遮掩后的授权码（前 4 位 + `****` + 后 4 位）

#### Scenario: 授权码为空

- **WHEN** `InitializeAsync()` 被调用
- **AND** `LicenseInfo.AuthToken` 为 null 或空
- **THEN** `AuthCode` MUST 显示空文本
- **AND** 授权码标签行 MUST 仍可见

---

### Requirement: 服务调用失败时显示默认值

`ProjectInfoWindowViewModel.InitializeAsync()` SHALL 在任何服务调用失败时不抛出异常，改为显示默认占位值。

#### Scenario: 认证服务不可用

- **WHEN** `IAuthenticationService.GetCurrentSessionAsync()` 抛出异常或返回 null
- **THEN** `ProjectName` MUST 显示 "获取失败"

#### Scenario: 授权服务不可用

- **WHEN** `ILicenseService.GetCurrentLicenseAsync()` 抛出异常或返回 null
- **THEN** `ExpirationDate`、`MachineCode`、`AuthCode` MUST 显示 "未授权"

#### Scenario: 设置服务不可用

- **WHEN** `ISettingsService.GetSettingsAsync()` 抛出异常
- **THEN** `ProductNameDisplay` MUST 保持默认空文本
