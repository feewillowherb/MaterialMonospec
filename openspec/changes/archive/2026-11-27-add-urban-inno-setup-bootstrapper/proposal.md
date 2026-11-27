# Proposal: Add Inno Setup D-Drive First-Install Bootstrapper for MaterialClient.Urban

## Why

Velopack 的 `MaterialClient.Urban-win-Setup.exe` 双击默认无弹窗安装至 `%LocalAppData%\MaterialClient.Urban`（C 盘），不支持直接修改双击默认路径。现场工控机通常希望客户双击单个安装程序即可默认安装到 `D:\MaterialClient.Urban`（也可浏览选盘），同时装完后继续由 Velopack 接管后续 195KB Delta OTA 增量升级。

## What Changes

1. **MaterialClient（打包脚本）**：
   - 新增 Inno Setup 6 脚本 `scripts/urban-installer.iss`：中文向导界面，默认安装路径自动选 `D:\MaterialClient.Urban`（无 D 盘时回退 `%LocalAppData%\MaterialClient.Urban`），允许客户自由选盘；设置 `Uninstallable=no` 与 `CreateUninstallRegKey=no`（卸载与更新完全交由 Velopack 管理），安装时静默执行内嵌 `MaterialClient.Urban-win-Setup.exe -s --installto "{app}"`。
   - 更新 `scripts/pack-urban-ota.ps1`：在 `vpk pack` 完成后自动调用本机 `ISCC.exe` 生成 `MaterialClient.Urban-Installer.exe` 到发布输出目录（可用 `-SkipInstaller` 跳过）。

2. **UrbanManagement.Admin（管理平台）**：
   - `OtaPackageCatalogService` 自动探测 `/updates/urban/MaterialClient.Urban-Installer.exe` 是否存在，存在时将「下载首次安装包」按钮指向 `MaterialClient.Urban-Installer.exe`，否则向后兼容回退至 `MaterialClient.Urban-win-Setup.exe`。

## Capabilities

### New Capabilities
- `urban-inno-setup-bootstrapper`: 结合 Inno Setup 中文选盘引导与 Velopack 原地 Delta OTA 的首次安装包生成与 Admin 下载入口。

## Impact

- **Repos**: `repos/MaterialClient`, `repos/UrbanManagement`
- **Compatibility**: 安装后的目录结构（`<InstallRoot>\current\`、`Update.exe`、`data\`）与 Velopack 100% 一致，所有既有 OTA 推送与看门狗机制零变更。
