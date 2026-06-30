## Context

MaterialClient.Urban 在 `MaterialClientUrbanModule.OnApplicationInitializationAsync` 中执行启动授权检查。授权无效时模块提前 `return`，SignalR（`IDeviceStatusSignalRClient`）、`ClientLogPullService`、`PollingBackgroundService` 等均未注册/启动。当前 `App.axaml.cs` 在 `UrbanLicenseRecoveryService.RecoverAsync` 激活成功后，于同进程继续显示 `UrbanAttendedWeighingWindow`，导致后台服务缺失，UrbanManagement 无法将客户端标记为在线。

`Program.cs` 使用 `MaterialClient_Urban_SingleInstance_Mutex` 保证单实例。若在旧进程仍持有 Mutex 时 `Process.Start` 新实例，新进程会因 `createdNew == false` 立即退出。

涉及入口：
- 启动未授权：`App.HandleUnauthorizedStartupAsync` → `UrbanLicenseRecoveryService.RecoverAsync`（`isStartup=true`）
- 运行时 F4：`LicenseDeviceRevokedEventHandler` → `RecoverAsync`（`isStartup=false`，对话框模式）

## Goals / Non-Goals

**Goals:**

- 在线激活成功（JWT 已持久化到 `LicenseInfo`）后，退出当前进程并在 Mutex 释放后自动拉起新实例。
- 新实例走完整冷启动：`OnApplicationInitializationAsync` 授权通过 → SignalR/轮询/设备服务正常启动。
- 启动恢复与 F4 运行时重激活采用统一重启机制。
- 用户取消激活时仍关闭应用，不重启。

**Non-Goals:**

- 不改造 UrbanManagement 服务端连接状态逻辑。
- 不在同进程内补启 SignalR/后台服务（重启即替代该方案）。
- 不增加配置开关允许「激活后继续同进程」（行为固定为重启）。
- 不修改激活 API 或 JWT 持久化逻辑（`ActivateUrbanAsync` 已满足）。

## Decisions

### D1: 在 `Program.Main` 末尾重启，而非激活回调内直接 `Process.Start`

**选择**：`App.RequestRestartOnExit = true` + `desktop.Shutdown()`；`StartWithClassicDesktopLifetime` 返回后、`using mutex` 释放完毕再 `Process.Start(Environment.ProcessPath)`。

**理由**：单实例 Mutex 在 `Main` 的 `using` 块内，旧进程未退出前新进程无法获得 Mutex。

**备选**：延迟 `Task.Delay` 后启动新进程 → 时序不可靠，弃用。

### D2: 重启标志用 `App` 静态属性，不引入新 DI 服务

**选择**：`public static bool RequestRestartOnExit { get; set; }` 由 `App` 与 `Program` 共享。

**理由**：`Program.Main` 在 ABP 容器之外，静态标志最简单；重启为一次性流程，无需长期服务。

**备选**：`IProcessRestartService` → 过度抽象，可在 tasks 中按需抽取私有静态方法。

### D3: 启动恢复与 F4 共用 `RequestProcessRestart(desktop)` 辅助方法

**选择**：`App.axaml.cs` 内私有方法设置标志并 `Shutdown()`；`LicenseDeviceRevokedEventHandler` 在 UI 线程激活成功后调用同一逻辑（可通过 `App` 静态方法暴露）。

**理由**：两条路径激活后需求一致；避免 F4 路径遗漏 SignalR 初始化问题。

### D4: 激活成功路径不显示称重主界面

**选择**：`HandleUnauthorizedStartupAsync` 在 `RecoverAsync` 返回 `true` 时调用重启并 `return false`，使 `OnFrameworkInitializationCompleted` 不进入主窗口分支。

**理由**：旧进程不应再启动硬件/称重；所有业务在新进程初始化。

### D5: 正常退出清理仍走 `OnApplicationExit`

**选择**：重启前注册 `desktop.Exit += OnApplicationExit`（与取消路径一致），确保串口、WebHost、ABP 有序释放。

**理由**：F4 运行时路径可能已打开硬件；重启前需清理避免 COM 口占用影响新进程。

### D6: 新进程启动参数与工作目录

**选择**：`ProcessStartInfo` 使用 `Environment.ProcessPath`、`UseShellExecute = true`、`WorkingDirectory = AppContext.BaseDirectory`；不传递额外 CLI 参数。

**理由**：授权状态已在 SQLite；冷启动自检即可。`dotnet run` 与发布 exe 均支持 `Environment.ProcessPath`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 重启瞬间用户看到应用闪退再打开 | 激活窗可在关闭前短暂提示「激活成功，正在重启…」（可选 UI 文案，非阻塞） |
| `OnApplicationExit` 清理超时（10s）延迟重启 | 重启在 `Main` 末尾，与清理并行结束；Mutex 在 `Main` 返回时释放 |
| F4 运行时重启丢失未保存 UI 状态 | 可接受；设备变更场景业务上应重新初始化 |
| 开发时 `Environment.ProcessPath` 为 dll 路径 | .NET 6+ 桌面应用通常指向 exe；实现时记录日志并在 dev 环境验证 |

## Migration Plan

1. 在 MaterialClient 子仓库实现 `Program.cs` / `App.axaml.cs` / `LicenseDeviceRevokedEventHandler` 变更。
2. 手动验证：启动过期授权 → 在线激活 → 自动重启 → 日志含 `SignalR client connection initiated` → UrbanManagement 显示在线。
3. 验证 F4：模拟 `DEVICE_CHANGED` → 重激活 → 自动重启。
4. 验证取消路径：关闭激活窗 → 进程退出，无新实例。
5. 无数据库迁移；无 UrbanManagement 部署依赖。

## Open Questions

- 是否在 `UrbanActivationWindow` 关闭前显示「正在重启」提示？（建议实现时加一行日志 + 可选 MessageBox，tasks 中列为可选）
