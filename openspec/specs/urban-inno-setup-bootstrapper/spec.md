# urban-inno-setup-bootstrapper Specification

## Purpose
TBD - created by archiving change add-urban-inno-setup-bootstrapper. Update Purpose after archive.
## Requirements
### Requirement: 默认 D 盘中文首次安装程序封装

打包流水线 SHALL 使用 Inno Setup 将 Velopack `MaterialClient.Urban-win-Setup.exe` 封装为中文选盘首次安装程序 `MaterialClient.Urban-Installer.exe`。

#### Scenario: 存在 D 盘时默认安装至 D:\MaterialClient.Urban
- **WHEN** 客户双击运行 `MaterialClient.Urban-Installer.exe` 且主机存在 `D:\`
- **THEN** 安装向导默认目标路径 SHALL 为 `D:\MaterialClient.Urban` 并允许客户浏览修改
- **AND** 安装向导 SHALL 以静默参数 `-s --installto "{app}"` 调用内嵌 Velopack `Setup.exe`
- **AND** Inno Setup SHALL NOT 写入重复的卸载注册表项（`Uninstallable=no`）

#### Scenario: 主机无 D 盘时自动回退 LocalAppData
- **WHEN** 主机不存在 `D:\`
- **THEN** 安装向导默认目标路径 SHALL 自动回退为 `%LocalAppData%\MaterialClient.Urban`

### Requirement: Admin 优先提供 Installer.exe 下载入口

Admin `/client-updates` 页面 SHALL 优先将「下载首次安装包」按钮指向 `MaterialClient.Urban-Installer.exe`，在缺失时向后兼容回退至 `MaterialClient.Urban-win-Setup.exe`。

#### Scenario: 更新源存在 MaterialClient.Urban-Installer.exe
- **WHEN** 管理员打开 `/client-updates` 且更新源存在 `MaterialClient.Urban-Installer.exe`
- **THEN** 「下载首次安装包」按钮 SHALL 下载 `/updates/urban/MaterialClient.Urban-Installer.exe`

