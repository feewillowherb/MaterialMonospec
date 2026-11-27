# selective-ota-push Specification

## Purpose
TBD - created by archiving change update-selective-ota-push-and-package-view. Update Purpose after archive.
## Requirements
### Requirement: 客户端默认仅响应 Admin 选择性推送

客户端在默认配置下 SHALL NOT 主动定时轮询拉取新版本，仅响应 Admin 针对该客户端下发的推送指令。

#### Scenario: 默认配置下上传新包不触发客户端自动更新
- **WHEN** `Ota:AutoCheckEnabled` 未显式配置（默认 `false`）且服务端 `/updates/urban/` 上传了新版本
- **THEN** `UrbanUpdateBackgroundWorker` SHALL NOT 调用 `CheckAndDownloadUpdateAsync`
- **AND** 若该客户端此前已收到 Admin 推送并处于 `ReadyToRestart` 状态，Worker SHALL 仍可在称重空闲（`OffScale`）时调用 `TryApplyPendingUpdateAsync` 完成生效

### Requirement: Admin 展示服务端安装包并支持按项目/客户端选择性推送

Admin `/client-updates` 页面 SHALL 展示服务端当前发布的安装包清单，并支持按项目/客户端筛选后单独确认推送。

#### Scenario: Admin 查看服务端安装包与下载首次安装程序
- **WHEN** 管理员打开 `/client-updates` 且网关 `/updates/urban/releases.win.json` 可访问
- **THEN** 页面 SHALL 展示服务端最新版本号、首次安装包（`MaterialClient.Urban-win-Setup.exe`）下载入口及已发布的 `Full` / `Delta` 包列表与大小

#### Scenario: 管理员对指定项目的指定客户端确认推送更新
- **WHEN** 管理员按项目名称或客户端标识筛选出目标客户端并点击「推送更新」
- **THEN** 页面 SHALL 弹出确认框明确显示目标项目名与客户端标识
- **AND** 管理员确认后系统 SHALL 仅向该单个 `ClientId` 下发 `TriggerUpdateAsync` 指令

