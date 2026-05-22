## Why

`MaterialClient.UI` 当前通过 `SettingsDialog` + `ISettingsSection` + 程序化 `SettingItems` 提供设置界面，功能远少于 MaterialClient 主程序 `main` 分支上的完整 `SettingsWindow`（7 个分区、摄像头/车牌 DataGrid、测试抓拍、道闸校验等）。用户打开设置时常出现侧栏或内容空白，且 Urban 与主程序无法共享同一套完整配置体验。需要将 **main 分支已验证的 `SettingsWindow` / `SettingsWindowViewModel` 实现** 迁入 `MaterialClient.UI` 作为唯一共享设置入口，并弃用 `MaterialClient.UI/Settings` 下的简化框架。

## What Changes

- 将 `MaterialClient` 工程中的 `SettingsWindow`、`SettingsWindowViewModel`、相关对话框（`AddCameraDialog`、`AddLprDialog`）及枚举转换器迁入 `MaterialClient.UI`（命名空间调整为 `MaterialClient.UI.*`）
- **移除** `MaterialClient.UI` 中的 `SettingsDialog`、`SettingsViewModel`、`ISettingsSection`、`Settings/Sections/*`、`Controls/SettingItems/*` 及 `MaterialClientUiModule` 内对应 DI 注册
- `MaterialClient` 主程序与 `MaterialClient.Urban` 的系统设置入口统一改为打开共享 `SettingsWindow`（经 DI 解析）
- `MaterialClient` 工程内删除或改为引用 UI 程序集的重复设置文件，避免双份维护
- `MaterialClient.UI` 增加 `Avalonia.Controls.DataGrid` 等 `SettingsWindow` 所需包引用；将 `brand-primary-button` 等窗口样式并入 `SharedTheme.axaml` 或窗口资源
- **BREAKING**：`settings-ui` 规范中关于 `SettingsDialog`、`ISettingsSection`、`SettingItems` 的要求将被替换为 `SettingsWindow` 要求
- **BREAKING**：`materialclient-urban-desktop` 中「打开 SettingsDialog」改为「打开 SettingsWindow」

本变更 **仅** 涉及设置窗口/UI 与入口接线，不包含设备状态栏、称重业务或其它无关重构。

## Capabilities

### New Capabilities

（无 — 行为在既有 capability 上修改）

### Modified Capabilities

- `settings-ui`：由 SettingsDialog 分区框架改为共享 SettingsWindow 完整实现
- `materialclient-urban-desktop`：系统设置入口与共享设置 UI 类型更新

## Impact

**受影响的代码（均在 `repos/MaterialClient/` 子仓库实现）：**

- `MaterialClient.UI/` — 迁入 Settings 相关 Views/ViewModels/Converters；删除 Settings 简化框架
- `MaterialClient/` — `AttendedWeighingViewModel.OpenSettings`、移除重复的 `Views/SettingsWindow*`（若已迁入 UI）
- `MaterialClient.Urban/` — `UrbanAttendedWeighingWindow` 系统设置点击处理
- `MaterialClient.UI/MaterialClientUiModule.cs` — 移除 `ISettingsSection` 注册

**不受影响（本 change 明确排除）：**

- `DeviceStatusBar`、`SharedDeviceStatusTracker`、摄像头悬停弹层等状态栏相关 UI
- OpenSpec 主仓库除本 change 工件外的其它 specs
- `MaterialClient.Common` 设置实体与服务接口（仅被 UI 消费，无破坏性 API 变更）

**依赖：**

- 实现仍以 [main 分支 SettingsWindowViewModel](https://github.com/feewillowherb/MaterialClient/blob/main/MaterialClient/ViewModels/SettingsWindowViewModel.cs) 为功能基准
- Urban/Main 继续引用 `MaterialClient.UI` + `MaterialClient.Common`
