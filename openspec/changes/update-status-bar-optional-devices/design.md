## Context

`MaterialClient.UI` 已提供共享 `DeviceStatusBar` 与 `DeviceStatusBarViewModel`。归档变更 `materialclient-urban-shared-ui-components-library` 规定主应用状态栏展示六项设备，Urban 仅三项。现场反馈：未启用的打印机、高拍仪等在状态栏显示「离线」造成误导；高拍仪缺少与打印机/音响类似的「启用 + 可选启动」设置入口。

既有模式：`SoundDeviceEnabled`、`IsPrinterEnabled`（或等价字段）已控制设置页控件可见性与部分服务行为；状态栏仍静态注册全量设备。本设计将**可见性规则**上推到 catalog 构建层，并新增高拍仪启用标志。

约束：ReactiveUI、ABP DI、`SettingsEntity` 持久化、OpenSpec 仅在 MaterialMonospec 主仓库。

## Goals / Non-Goals

**Goals:**

- 设置窗口提供高拍仪分区：启用开关、必要连接参数、测试入口（与 main 分支打印机/音响分区交互模式一致）
- 应用启动与保存设置时：未启用高拍仪则不启动 USB/文档摄像头服务
- 状态栏默认仅展示地磅、海康摄像头、车牌识别
- 高拍仪、打印机、音响仅在对应 `*Enabled` 为 true 时加入状态栏并订阅状态事件
- 启用状态变更（保存设置或运行时重载，若已有）后状态栏增删项与事件订阅一致

**Non-Goals:**

- 不重构 `SettingsWindow` 整体架构（沿用 `replace-ui-settings-with-settings-window` 整窗方案）
- 不改变海康摄像头、车牌、地磅的默认必显语义
- 不实现「保存后自动重启全部设备」的通用 TODO（可留后续 change）
- 不修改 Urban 顶栏、登录、称重主流程布局
- 不在此变更中新增高拍仪抓拍业务场景（仅配置与状态可见性）

## Decisions

### 决策 1：持久化字段 `DocumentCameraEnabled`

**选择：** 在 `SettingsEntity` / `SystemSettings` 增加 `DocumentCameraEnabled`（bool，默认 `false`），经 `ISettingsService` 与现有打印机/音响启用字段一并读写。

**备选：** 仅根据 USB 设备是否连接推断 — 否决，无法表达「故意不用高拍仪」。

**理由：** 与 `SoundDeviceEnabled`、`IsPrinterEnabled` 一致，可驱动启动与 UI。

### 决策 2：高拍仪 UI 并入 `SettingsWindow` 第八分区

**选择：** 在共享 `SettingsWindow` 左侧导航增加「高拍仪」项，内容含启用 Toggle、设备选择/路径（与现有 USB 摄像头配置字段对齐）、测试按钮（若服务已存在）。

**备选：** 并入「摄像头」分区 — 否决，海康称重相机与高拍仪职责不同，易混淆。

**理由：** 用户明确要求「设置中新增高拍仪设置」。

### 决策 3：动态 `IDeviceStatusCatalog`（或 VM 内 `RebuildDevices()`）

**选择：** 抽取或扩展 catalog 方法：`GetVisibleDevices(ISettingsService)` 返回有序设备键列表。规则：

| 设备键 | 显示条件 |
|--------|----------|
| Scale | 始终 |
| Camera (Hikvision) | 始终（可多条合并展示策略保持现行为） |
| LPR | 始终 |
| DocumentCamera / USB | `DocumentCameraEnabled == true` |
| Printer | `IsPrinterEnabled == true` |
| Sound | `SoundDeviceEnabled == true` |

**备选：** XAML 层 `IsVisible` 绑定 — 否决，仍会订阅无效服务且占位。

**理由：** 未启用时不创建 `DeviceStatusItem`，满足「不要在状态栏中显示」。

### 决策 4：启动管线尊重启用标志

**选择：** `IDeviceManagerService`（或等价启动器）在 `StartAsync` 时跳过未启用的打印机、音响、高拍仪；已启动后用户在设置中禁用并保存时，停止服务并从状态栏移除（与现有 Restart 行为对齐，至少在下一次窗口/应用生命周期生效）。

**备选：** 仅隐藏 UI 仍启动服务 — 否决，浪费资源且事件仍触发。

**理由：** 「可选启动项」语义要求未启动即无状态栏项。

### 决策 5：Urban 与主应用共用 catalog

**选择：** Urban 不单独硬编码三项；共用动态 catalog，因 Urban 默认不启用打印机/音响/高拍仪时自然仅显示三项。

**理由：** 避免双份逻辑；Urban 规范已要求默认三设备。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 与 `update-urban-settings-statusbar-parity` 方向冲突 | 以本 change 为准；parity 归档前合并或废弃 parity 中「始终显示六项」的 delta |
| 保存设置后状态栏未刷新 | `SettingsSavedMessage` 或保存成功后调用 `DeviceStatusBarViewModel.RefreshCatalogAsync()` |
| 字段命名与现有 USB 摄像头代码不一致 | 实施时对齐现有 `UsbCamera` 服务与配置键，规范使用逻辑名「高拍仪」 |
| 启用高拍仪但无硬件仍显示离线 | 可接受：与摄像头一致，表示已启用但未连接 |

## Migration Plan

1. 添加 `DocumentCameraEnabled` 及迁移默认值 `false`（JSON 反序列化缺省即可）
2. 实现设置分区与 VM 绑定
3. 调整设备启动与 catalog 动态逻辑
4. 主应用 + Urban 手动验证：默认三行；勾选打印机/高拍仪后保存，状态栏出现对应项；取消勾选后项消失
5. `openspec validate update-status-bar-optional-devices --strict`

**回滚：** 恢复静态六项 catalog；移除设置分区；保留 DB 新字段无害。

## Open Questions

- 现有代码中 USB 摄像头服务类名与配置结构（实施时在子仓库确认并映射到「高拍仪」文案）
- 保存设置后是否在同一会话内调用 `IDeviceManagerService.RestartAsync()`（建议本 change 在 tasks 中列为验证项，不阻塞归档）
