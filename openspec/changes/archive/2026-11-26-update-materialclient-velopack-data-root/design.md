# Design: Velopack 同盘外置数据根目录（`..\data\`）隔离

## Context

Velopack 在 Windows 上将应用安装至用户指定的任意盘符目录：

```text
<InstallRoot>\                (例如 D:\MaterialClient\Urban\)
├── current\                  ← AppContext.BaseDirectory（OTA 每次替换此目录）
│   └── MaterialClient.Urban.exe
├── data\                     ← PathManager.DataRoot（OTA 永不触碰）
│   ├── MaterialClient.db
│   ├── Logs\
│   ├── PhotoJianKong\ / Lpr\ / PhotoUrban\
│   └── (可选) appsettings.json / appsettings.secret.json
├── packages\
└── Update.exe
```

而在开发调试（`bin\Debug\net10.0\win-x64\`）或传统绿色部署目录中，上级不存在 `Update.exe` 且目录名不为 `current`，此时 `PathManager.DataRoot` 自动回退为 `AppContext.BaseDirectory`（exe 同目录）。

## Decisions

### 1. 唯一数据根目录解析器：`PathManager.ResolveDefaultDataRoot`

在 `MaterialClient.Common/Utils/PathManager.cs` 新增纯静态方法：

- 输入：`string? executableDirectory = null`（默认 `AppContext.BaseDirectory`）。
- 判定规则：
  1. 规范化绝对路径并去掉末尾分隔符；
  2. 若当前目录名为 `current`（`StringComparison.OrdinalIgnoreCase`）**且**父目录存在文件 `Update.exe`：
     - 目标数据目录为 `Path.Combine(parent.FullName, "data")`；
     - 自动调用 `Directory.CreateDirectory(dataDir)` 确保目录存在；
     - 返回 `dataDir`。
  3. 否则返回可执行目录本身（与原有 `AppContext.BaseDirectory` 行为一致）。

### 2. 全仓 8 处运行期数据路径统一收口

| 位置 | 改动 |
|---|---|
| `PathManager.cs` | `_appBaseDirectory` 初始化与 `ResetDataRoot()` 调用 `ResolveDefaultDataRoot()` |
| `MaterialClientConfigurationDefaults.cs` | `ResolveExeDirectoryConnectionString`（保留签名兼容）改用 `PathManager.DataRoot` 作为默认基目录 |
| `SerilogFileLogConfigurator.cs` | 相对 `Log:Directory` 基于 `PathManager.DataRoot` 解析 |
| `ClientLogPullService.cs` | 相对 `Log:Directory` 基于 `PathManager.DataRoot` 解析 |
| `LocalImageCleanupService.cs` | 无参 `CleanupAsync` 基于 `PathManager.DataRoot` |
| `HikvisionService.cs` | `TestImage` 目录基于 `PathManager.DataRoot` |
| `TicketPrintingService.cs` | 相对 PDF/预览图输出路径基于 `PathManager.DataRoot` |
| `MaterialClientModule` / `MaterialClientUrbanModule` / `MaterialClientRecycleModule` | 当 `PathManager.DataRoot` 不同于 `AppContext.BaseDirectory` 时，追加加载 `PathManager.DataRoot` 下的可选 `appsettings.json` 与 `appsettings.secret.json` |

### 3. 零新增 DI 服务

遵循 `traits/minimal-di-trait.md`，所有路径解析均放在既有静态类 `PathManager` 与 `MaterialClientConfigurationDefaults` 中，不引入任何新 Service。

## Risks / Trade-offs

- **并发测试隔离**：若测试调用 `PathManager.UseDataRoot(...)`，测试结束须调用 `PathManager.ResetDataRoot()` 恢复默认状态；新单测优先直接测试 `PathManager.ResolveDefaultDataRoot(tempDir)` 纯函数，不污染全局静态状态。
- **Standard / SolidWaste 存量 `HostBootstrap` 兼容**：`HostBootstrap.Prepare` 在检测到显式 `Client:DataDirectory` 时仍会调用 `PathManager.UseDataRoot(...)` 覆盖默认值，二者完全兼容。
