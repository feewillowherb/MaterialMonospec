## Why

LPR 图片当前落在扁平的 `Lpr/` 目录，与枪机 Camera 照片的 `年/月/日` 结构不一致，目录膨胀后难于运维与按日排查。Urban 枪机 `UrbanPhoto` 另占 `PhotoUrban/`，与 LPR 分散，不利于统一清理。同时本地磁盘上累积的 Camera / Lpr 图片缺乏自动清理，长期运行会占满磁盘。

## What Changes

- LPR 落盘路径改为日期目录：`Lpr/{yyyy}/{MM}/{dd}/`（通过 `AttachmentPathUtils.GetLocalStorageAbsolutePath(AttachType.Lpr, …)`）。
- **`AttachType.UrbanPhoto` 的本地根目录改为与 LPR 相同的 `Lpr`**（`GetBasePath(UrbanPhoto)` → `"Lpr"`），新落盘为 `Lpr/{yyyy}/{MM}/{dd}/`；`AttachType` 枚举值与业务语义不变，仅磁盘根合并。
- Hikvision / Vzvision 的 `TrySave*LprAttachment` 写入日期路径；相对路径仍经 `PathManager.ToRelativePath` 写库。
- 新增可配置的本地图片清理后台任务：**所有产品客户端均具备**（Standard / SolidWaste 所在的 `MaterialClient`、`MaterialClient.Urban`、`MaterialClient.Recycle`）；默认约每天执行一次，删除保留期（默认 3 个月）之前的 `PhotoJianKong`（非 Urban 枪机）、`Lpr`（含 UrbanPhoto + LPR），以及对历史 `PhotoUrban/` 的兼容清理。
- 启用开关、执行频率、保留时长、启动后首次延迟均可在各客户端 `appsettings.json` 中配置；**默认启用**。
- 清理仅删磁盘文件，不修改数据库中的 `AttachmentFile` 记录。
- 不迁移历史扁平 `Lpr/` 或旧 `PhotoUrban/` 文件；清理任务可按目录日 / LastWriteTime 处理。

## Capabilities

### New Capabilities

- `local-image-retention-cleanup`：**全部产品客户端**本地枪机/Lpr 图片按保留期自动清理，及统一配置契约。
- `client-local-attachment-path`：客户端本地附件根路径约定（含 UrbanPhoto 与 Lpr 共用 `Lpr` 根、日期目录结构）。

### Modified Capabilities

- `license-plate-recognition`：LPR 附件落盘路径从扁平 `Lpr/` 改为 `Lpr/{yyyy}/{MM}/{dd}/`。

## Impact

- **MaterialClient.Common**：`AttachmentPathUtils.GetBasePath`；`HikvisionLprService` / `VzvisionLprService` 落盘；清理服务及 `ImageCleanupOptions`。
- **Urban 抓拍**：`WeighingCaptureService` 在 UrbanMode 仍用 `AttachType.UrbanPhoto`，因根改为 `Lpr`，文件落在 `Lpr/...`。
- **注册方式**：清理 Worker 在 `MaterialClientCommonModule` **统一注册**（一次实现，所有依赖 Common 的产品宿主自动具备）；禁止仅部分客户端挂载。
- **配置**：Standard / Urban / Recycle 三套 `appsettings.json` 均增加 ImageCleanup 段（Toolkit 如依赖 Common 完整启动，可设 `Enabled=false` 或沿用默认）。
- **非 BREAKING**：相对路径读图逻辑不变；历史 `PhotoUrban/` 与扁平 `Lpr/` 仍可读直至被清理。
- **范围外**：不清理 `PhotoPiaoJu`、`LprDebug`；不改 UrbanManagement 服务端布局；非产品入口（纯 Toolkit 运维工具）不强制要求开启清理。
