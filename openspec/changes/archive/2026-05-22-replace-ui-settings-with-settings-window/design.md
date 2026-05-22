## Context

`MaterialClient.UI` 在 `materialclient-urban-shared-ui-components-library` 变更中引入了 `SettingsDialog` + `ISettingsSection` 插件式设置框架。该实现仅覆盖少量字段（程序化 `SettingItems`），与 MaterialClient `main` 分支上成熟的 `SettingsWindow`（约 840 行 XAML + `SettingsWindowViewModel`）功能差距大，且存在编译绑定、DI 解析等问题导致空白界面。

完整版 `SettingsWindow` 仍保留在 `MaterialClient` 工程中，但 Urban 无法引用主工程；主程序入口又优先打开 `SettingsDialog`。本设计将 **main 分支设置实现整体迁入 `MaterialClient.UI`**，供 Main 与 Urban 共用，并删除 UI 内简化 Settings 目录。

约束：OpenSpec 工件仅在 MaterialMonospec 主仓库；代码仅在 `repos/MaterialClient`；本 change **不** 修改设备状态栏、称重管线或其它模块。

## Goals / Non-Goals

**Goals:**

- `MaterialClient.UI` 提供与 main 分支行为一致的共享 `SettingsWindow` 及 `SettingsWindowViewModel`
- 主程序与 Urban 通过 DI 打开同一设置窗口，覆盖地磅、称重、摄像头、车牌、系统、音响、打印机等 7 个分区及关联命令（增删设备、测试抓拍/音响等）
- 移除 `SettingsDialog`、`ISettingsSection`、`Settings/Sections`、`SettingItems` 及相关模块注册
- 更新 `settings-ui` 与 `materialclient-urban-desktop` 规范以反映新共享方式

**Non-Goals:**

- 不新增业务字段或改变 `SettingsEntity` 持久化结构（与 main VM 保存逻辑一致即可）
- 不实现 `SettingsService` 中「保存后重启全部设备」的 TODO（可留作后续 change）
- 不迁移 Semi/Ursa 等主程序专属全局主题（仅补齐 `SettingsWindow` 所需样式类）
- 不修改 `DeviceStatusBar`、摄像头状态栏悬停弹层

## Decisions

### 决策 1：整窗迁入 `MaterialClient.UI`，而非保留双份

**选择：** 将 `SettingsWindow.axaml(.cs)`、`SettingsWindowViewModel.cs`（含 `CameraConfigViewModel`、`LicensePlateRecognitionConfigViewModel`）、`AddCameraDialog`/`AddLprDialog` 及 ViewModel、`ScaleUnitConverter` 等转换器迁入 `MaterialClient.UI`，命名空间统一为 `MaterialClient.UI.Views` / `ViewModels` / `Converters`。

**备选：**

- *Urban 引用 MaterialClient 主工程*：强耦合，否决
- *仅主程序用 SettingsWindow、Urban 保留 SettingsDialog*：双轨维护，否决

**理由：** Urban 已引用 UI；整窗迁入后单一代码路径，与 GitHub main 用户体验一致。

### 决策 2：删除简化 Settings 框架

**选择：** 删除 `Controls/SettingsDialog.*`、`ViewModels/SettingsViewModel.cs`、`Abstractions/ISettingsSection.cs`、`Settings/Sections/*.cs`、`Controls/SettingItems/*`，并从 `MaterialClientUiModule` 移除 `ISettingsSection` 注册。

**理由：** 避免两套 VM 并存、避免 Autofac 误解析 `SettingsViewModel`。

### 决策 3：主程序删除重复文件并改入口

**选择：** `MaterialClient` 内移除已迁入 UI 的重复 Settings 文件；`AttendedWeighingViewModel.OpenSettings` 仅 `GetRequiredService<SettingsWindow>()` 并 `ShowDialog`。

**理由：** 防止类型重复与命名空间混淆。

### 决策 4：UI 工程依赖与样式

**选择：**

- `MaterialClient.UI.csproj` 增加 `Avalonia.Controls.DataGrid`
- `brand-primary-button` 并入 `Styles/SharedTheme.axaml`（或 `SettingsWindow.Window.Styles`）
- 窗口 `Icon` 不设死路径，由调用方可选设置，或去掉 `Icon` 避免 UI 程序集缺少 `fd-ico.ico`

**理由：** DataGrid 为摄像头/车牌表格必需；Urban/Main 各自有图标资源。

### 决策 5：保存副作用保持 main 行为

**选择：** 保留 `SettingsWindowViewModel.SaveAsync` 现有逻辑：`ISettingsService.SaveSettingsAsync`、`_truckScaleWeightService.RestartAsync()`、`MessageBus` 发送 `DetailCloseRequestedMessage`（类型已在 Common）。

**备选：** 保存后增加 `IDeviceManagerService.RestartAsync()` — 作为可选 follow-up，本 change 不强制。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| XAML 命名空间/转换器资源路径错误导致编译或绑定失败 | 迁入时统一改 `xmlns`；Converters 放入 `SettingsWindow` 资源或 SharedTheme |
| `SettingsWindow` 体积大，UI 库编译变慢 | 可接受；功能完整性优先 |
| Urban 展示主程序专用项（如供应商推荐）但业务未使用 | 与 main 一致；字段可保存，Urban 管线可忽略 |
| 保存后摄像头/LPR 未自动重载 | 与 main 相同限制；文档注明需重启应用或后续 change |
| 归档时 `settings-ui` 与旧 archive delta 冲突 | 本 change delta 明确 REMOVED 旧要求 |

## Migration Plan

1. 在 `MaterialClient.UI` 添加包引用并迁入 Settings 相关源文件（以 main 为基准）
2. 更新 SharedTheme / 窗口资源
3. 删除 UI 简化 Settings 文件并精简 `MaterialClientUiModule`
4. 更新 Main/Urban 打开设置入口
5. 删除 `MaterialClient` 重复 Settings 文件
6. 编译 Main + Urban；手动验证 7 分区可见、保存、测试抓拍/音响
7. `openspec validate replace-ui-settings-with-settings-window --strict` 后实施；完成后归档

**回滚：** 恢复 UI 内 `SettingsDialog` 文件与入口接线（Git revert 子仓库提交）。

## Open Questions

- 是否在 `SaveAsync` 中增加 `IDeviceManagerService.RestartAsync()`（建议本 change 末尾任务标为可选验证项，不阻塞归档）
- `MaterialClient` 工程是否保留 `using` 别名指向 UI 的 `SettingsWindow` 以减少 XAML 设计器路径变更 — 实现时优先直接改命名空间
