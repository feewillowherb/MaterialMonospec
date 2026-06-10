## Why

主应用设备状态栏当前固定展示地磅、海康摄像头、USB 高拍仪、打印机、音响与车牌识别共六项，即使用户未启用或未启动对应外设也会显示为「离线」，干扰现场判断且占用状态栏空间。高拍仪尚无独立设置分区与「可选启动」开关，无法与打印机、音响等可选设备采用一致的产品模型。需要将状态栏默认收敛为称重核心三路（地磅、摄像头、车牌识别），并为高拍仪与打印机（及同类可选外设）提供「启用才显示、未启用不占位」的行为。

## What Changes

- 在 `SettingsWindow` 中新增**高拍仪设置**分区（或等价区域），提供「启用高拍仪」开关及连接/测试相关配置；未启用时应用启动不初始化高拍仪服务
- 设备状态栏**默认仅显示**：地磅设备、摄像头（海康称重相机）、车牌识别
- **高拍仪**：仅当设置中已启用且服务已纳入启动流程时，状态栏才显示高拍仪（USB 摄像头）指示项；未启用时不得出现占位项
- **打印机**：仅当设置中已启用打印机（`IsPrinterEnabled` 或等价持久化字段为 true）时，状态栏才显示打印机指示项；未启用时不得显示
- **音响设备**（主应用既有）：与打印机相同规则——仅启用时在状态栏显示（本变更不扩展音响业务能力，仅对齐可见性规则）
- 更新 `DeviceStatusBarViewModel`（或等价 catalog）按运行时启用状态动态增删 `DeviceStatusItem`，而非静态注册全量设备
- 更新 `device-status-bar`、`settings-ui`、`system-configuration` 规范；Urban 主界面默认三设备展示与现规范一致，仅需确认共享 catalog 变更后仍满足

## Capabilities

### New Capabilities

- `document-camera-settings`: 高拍仪（USB/文档摄像头）启用开关、配置持久化、可选启动与设置 UI

### Modified Capabilities

- `device-status-bar`: 默认设备集合改为地磅/摄像头/车牌识别；可选设备（高拍仪、打印机、音响）按启用状态动态显示
- `settings-ui`: 设置窗口增加高拍仪分区；`SettingsWindowViewModel` 加载/保存高拍仪启用及相关字段
- `system-configuration`: 持久化高拍仪启用标志（及必要配置键），与设备管理器启动逻辑一致

## Impact

**受影响的代码（`repos/MaterialClient` 子仓库，实施阶段）：**

- `MaterialClient.UI/ViewModels/DeviceStatusBarViewModel.cs`（或 `IDeviceStatusCatalog`）— 动态设备列表
- `MaterialClient.UI/Views/SettingsWindow.axaml` + `SettingsWindowViewModel.cs` — 高拍仪分区与绑定
- `MaterialClient.Common` — `SettingsEntity` / `SystemSettings` 新增或暴露 `DocumentCameraEnabled`（命名以实现为准）
- 设备管理 / USB 摄像头服务启动路径 — 尊重启用开关，未启用不启动
- `MaterialClient` 与 `MaterialClient.Urban` 主窗口 — 消费共享状态栏，Urban 无额外设备项需求

**规范与并行变更：**

- 与进行中的 `replace-ui-settings-with-settings-window`、`update-urban-settings-statusbar-parity` 可能重叠；本变更以「默认三设备 + 可选外设按需显示」为准，**取代** parity 变更中「主应用与 Urban 状态栏设备集合完全一致且始终展示六项」的意图

**不受影响：**

- UrbanManagement Web
- 称重管线核心业务逻辑（除高拍仪未启用时跳过启动）
