# Proposal: Selective OTA Push and Admin Package Catalog View

## Why

1. **避免上传新包触发全量自动更新**：当前 `MaterialClient.Urban` 的 `UrbanUpdateBackgroundWorker` 默认每 30 分钟自动检查并应用 `/updates/urban/` 的新版本，导致运维上传新包后所有在线工控机都会被动全量升级，不符合“由管理员针对某个项目的某个客户端选择性推送”的运维习惯。
2. **Admin 看不到服务端已上传的安装包**：当前 `/client-updates` 页面只展示在线客户端列表，未读取展示 `/updates/urban/releases.win.json` 中的版本与 `Setup.exe` / `Full` / `Delta` 制品，且将不常用的「指定更新源」输入框直接暴露在顶部，用户难以理解页面逻辑。

## What Changes

1. **MaterialClient.Urban（客户端）**：
   - `OtaOptions` 新增 `AutoCheckEnabled`（默认 `false`），默认禁止后台定时主动拉取新版本。
   - `UrbanUpdateBackgroundWorker` 在 `AutoCheckEnabled == false` 时仅负责对已被 Admin 推送并下载完毕、因称重忙碌延后的 `ReadyToRestart` 更新在空闲态（`OffScale`）完成重启生效，不主动拉取未推送的新版本。

2. **UrbanManagement.Admin（管理平台）**：
   - 新增 `IOtaPackageCatalogService` / `OtaPackageCatalogService` 读取网关 `/updates/urban/releases.win.json`（容器内优先 `http://um-gateway:8080`，本地回退 `NavigationManager.BaseUri`）。
   - 改造 `/client-updates`（`ClientUpdates.razor`）：
     - 顶部新增「服务端安装包与版本」卡片：展示最新版本号、一键下载首次安装包（`Setup.exe`）按钮，以及已发布的 `Full` / `Delta` 包明细（版本、类型、大小、下载链接）。
     - 下方「在线客户端与选择性推送」区域：增加按项目名称 / 客户端标识筛选、对比当前版本与服务端最新版（落后时高亮提示可升级）、单客户端「推送更新」二次确认弹窗（明确展示目标项目、客户端标识与目标版本），并将「指定更新源」折叠进高级选项。

## Capabilities

### New Capabilities
- `selective-ota-push`: 客户端默认仅响应 Admin 按项目/客户端选择性推送的 OTA 更新策略，以及 Admin 服务端安装包目录可视化与确认推送体验。

## Impact

- **Repos**: `repos/MaterialClient`, `repos/UrbanManagement`
- **Compatibility**: 既有远程触发命令 `ReceiveOtaTriggerCommand` 与网关 `/updates/urban` 静态协议保持不变。
