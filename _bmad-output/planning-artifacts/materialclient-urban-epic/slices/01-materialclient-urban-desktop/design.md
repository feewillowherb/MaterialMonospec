## Context

MaterialClient 主程序为多页面 + 登录。Urban 为单窗口桌面端，UI 已有 Demo 视觉草稿。

## Goals / Non-Goals

**Goals**

- `dotnet run` 启动即显示称重主界面（1280×800 量级，与 Demo 一致）
- 布局四行：标题栏 / 重量区 / 列表+照片侧栏 / 设备状态栏
- 配置与授权后台日志

**Non-Goals**

- 登录页、授权页、第二业务窗口
- 完整业务绑定（slice 02）、上传（slice 03）

## Decisions

1. **应用类型**：`AppBuilder.Configure<App>().UsePlatformDetect()` + Avalonia `ApplicationLifetime` 单主窗。
2. **主 View**：复制并调整 `WeighingSystemWindow.axaml` → `MaterialClient.Urban/Views/`；Code-behind + `WeighingSystemViewModel` 骨架。
3. **启动路由**：`OnFrameworkInitializationCompleted` → `desktop.MainWindow = new WeighingSystemWindow()`；**无** `ShowLogin()`。
4. **授权**：`StaticAuthChecker` 在模块 `OnApplicationInitialization` 调用；不向 UI 暴露状态（可选仅 Debug 状态栏文案）。
5. **顶栏菜单**：Demo 中「系统设置/项目信息/数据同步/退出登录」— Urban 首期隐藏或仅保留设置入口，**禁止**「退出登录」。
6. **样式**：复用 Demo 中已定义 `Style`（`tab-btn`、`search-btn`、DataGrid 等）或抽到 Urban `App.axaml` Resources。
7. **设备 ID**：在 `UrbanAppModule` 注册 **`IDeviceIdentityProvider` → `FixedConfigurationDeviceIdentityProvider`**，绑定 `IOptions<UrbanOptions>` 中的 **`FixedDeviceGuid`**；无效 Guid 启动时 **FailFast** 或 Error 日志（OpenSpec 二选一）。

详见 `../../ui-layout-reference.md`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Demo 与生产项目结构不同 | 仅迁移 AXAML + 样式；ViewModel 接正式服务 |
| 误加登录流程 | Code review + 无 Account 模块依赖 |
