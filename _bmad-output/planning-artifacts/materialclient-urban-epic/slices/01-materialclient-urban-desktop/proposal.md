## Why

城市管理需要 **UrbanMode = 201 专用 Avalonia 桌面端**：启动即进入唯一称重主界面，配置与 MaterialClient 类似，无登录/授权页面，静态授权仅在启动时后台打日志。本 slice 建立 `MaterialClient.Urban` 工程、单窗口 UI（布局草稿见 Demo `WeighingSystemWindow.axaml`）与 Urban 配置。

## What Changes

- 新增 **`MaterialClient.Urban`** Avalonia 可执行项目（.NET 10），引用共享 Domain/Application/Infrastructure。
- **`UrbanMode = 201`**、默认 **`ProductCode = 5030`**。
- **`IStaticLicenseChecker`**：启动时读 `LicenseFilePath`，仅日志，**无授权 UI**。
- **`App.axaml`**：启动后直接打开 **唯一主窗口**（`WeighingSystemWindow` 或 Urban 正式命名），**无** LoginWindow / LicenseWindow / 页面导航壳。
- 从 **`MaterialClient.Demo/Views/WeighingSystemWindow.axaml`** 迁移布局到 Urban 项目（View + 占位 ViewModel）；精简顶栏：移除「退出登录」等与登录相关项（见 `ui-layout-reference.md`）。
- **不**使用 Generic Host 作为交付形态；**不**注册主 MaterialClient 的登录/Session 模块。

## Capabilities

### New Capabilities

- `materialclient-urban-desktop`: Urban 桌面端、单主界面、UI 草稿落地、ProductCode 5030 / WeighingMode 201、静态授权启动日志。

### Modified Capabilities

- 共享 `WeighingMode` 枚举：增加 `UrbanMode = 201`（定位现有 spec 后 delta）。

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient |
| **目录** | `MaterialClient.Urban/`（Views、ViewModels、App.axaml）、解决方案项 |
| **参考** | `MaterialClient.Demo/Views/WeighingSystemWindow.axaml` |
| **依赖** | Avalonia、ReactiveUI（与主客户端一致） |
