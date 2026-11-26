# Change: 统一 MaterialClient 运行期数据根目录以支持 Velopack 同盘外置隔离

## Why

MaterialClient 计划采用 **Velopack** 实现无人值守工控机远程推送更新（OTA）。Velopack 将每个版本安装在 `<InstallRoot>\current\` 下并在更新时整体替换 `current\` 目录；而当前代码中有 8 处将运行期数据（SQLite 数据库、照片、日志、日志拉取、图片清理、抓拍测试图、磅单输出、可选 `appsettings*.json`）直接绑定到 `AppContext.BaseDirectory`（即 `current\`）。如果不做数据目录隔离，每次 Velopack 升级替换 `current\` 都会导致现场数据库和照片丢失。

同时，工控机 C 盘空间有限且用户需要任意盘符安装与绿色便携运维，因此数据目录不应写死在 C 盘，而应采用「Velopack 模式下自动落到同盘同级 `..\data\`，非 Velopack（F5 调试 / 绿色解压）模式下保持 exe 同目录」的统一解析机制。

## What Changes

- **在 `PathManager` 中新增 Velopack 自动识别的数据根目录解析**：
  - 新增 `PathManager.ResolveDefaultDataRoot(string? executableDirectory = null)`：当可执行目录名为 `current`（忽略大小写）且父目录存在 `Update.exe` 时，自动定位并确保创建 `<InstallRoot>\data`；否则保持可执行目录（`AppContext.BaseDirectory`）。
  - `PathManager.DataRoot` 与 `PathManager.ResetDataRoot()` 默认使用 `ResolveDefaultDataRoot()`。
- **将全部运行期数据与日志路径统一收口至 `PathManager.DataRoot`**：
  - `MaterialClientConfigurationDefaults.ResolveDataRootConnectionString()`（原 `ResolveExeDirectoryConnectionString` 同步委托）：SQLite 连接固定指向 `PathManager.DataRoot\MaterialClient.db`；
  - `SerilogFileLogConfigurator` 与 `ClientLogPullService`：日志写入与 Admin 日志拉取统一基于 `PathManager.DataRoot`；
  - `LocalImageCleanupService`、`HikvisionService`（测试抓拍）、`TicketPrintingService`（磅单 PDF/图片输出）：统一基于 `PathManager.DataRoot`；
  - `MaterialClientModule`、`MaterialClientUrbanModule`、`MaterialClientRecycleModule`：当 `PathManager.DataRoot` 不同于 `AppContext.BaseDirectory` 时，同时加载 `PathManager.DataRoot` 下的可选 `appsettings.json` 与 `appsettings.secret.json`，保证外置覆写配置与过渡期密钥文件在 OTA 升级后持续生效。

## Capabilities

### Modified Capabilities
- `client-configuration-defaults`: 更新 SQLite 连接字符串与运行期数据根目录解析规范，支持 Velopack `current\` + `Update.exe` 结构下自动切换至同盘同级 `..\data\`，非 Velopack 结构下保持 exe 同目录。

## Impact

- **受影响仓库**：仅 `repos/MaterialClient`（Mode A：Trunk-direct，分支名 `update-materialclient-velopack-data-root`）。
- **受影响项目**：`MaterialClient.Common`、`MaterialClient`、`MaterialClient.Urban`、`MaterialClient.Recycle`、`MaterialClient.Common.Tests`。
- **兼容性**：完全向后兼容。未通过 Velopack 安装的本地开发与现有绿色部署路径 100% 保持 exe 同目录不变。
