## 1. 本地路径约定（UrbanPhoto → Lpr）

- [ ] 1.1 修改 `AttachmentPathUtils.GetBasePath`：`AttachType.UrbanPhoto` 返回 `"Lpr"`（与 `AttachType.Lpr` 相同）；更新相关 XML 注释
- [ ] 1.2 补充/更新针对 `GetBasePath` / `GetLocalStoragePath` 的单测：UrbanPhoto 与 Lpr 均为 `Lpr/{yyyy}/{MM}/{dd}/`；EntryPhoto 仍为 `PhotoJianKong/...`

## 2. LPR 日期目录落盘

- [ ] 2.1 修改 `HikvisionLprService.TrySaveLprAttachment`：用 `AttachmentPathUtils.GetLocalStorageAbsolutePath(AttachType.Lpr)` 替代扁平 `EnsureDirectoryExists("Lpr")`
- [ ] 2.2 修改 `VzvisionLprService.TrySaveVzLprAttachment`：同上
- [ ] 2.3 如有针对扁平 `Lpr/` 路径断言的单测，更新为期望 `Lpr/{yyyy}/{MM}/{dd}/`

## 3. 清理配置与服务

- [ ] 3.1 在 Common 新增 `ImageCleanupOptions`（Enabled / RetentionDays / IntervalHours / PreferredStartHour），section：`BackgroundServices:ImageCleanup`
- [ ] 3.2 实现 `ILocalImageCleanupService`：扫描 `PhotoJianKong`、`Lpr`、历史 `PhotoUrban`；日期目录按目录日；扁平文件按 LastWriteTime；`RetentionDays < 1` 跳过；单文件失败记 Warning
- [ ] 3.3 为清理服务补充单元测试（过期删、保留期内保留、扁平旧文件、历史 PhotoUrban）

## 4. 后台 Worker（Common 统一注册，全客户端）

- [ ] 4.1 Common 增加 `Volo.Abp.BackgroundWorkers` 依赖（若尚未引用）；实现 `ImageCleanupBackgroundService`：读 options 设 Period；调用清理服务；可选对齐 PreferredStartHour
- [ ] 4.2 在 `MaterialClientCommonModule` 中按 `Enabled` 条件 `AddBackgroundWorkerAsync`（**不在**各宿主分别复制注册；保证 Standard/Urban/Recycle 全部具备）
- [ ] 4.3 更新 Standard / Urban / Recycle 三套 `appsettings.json` 的 `BackgroundServices:ImageCleanup`（默认 Enabled=true, RetentionDays=90, IntervalHours=24, PreferredStartHour=3）；Toolkit 如需可显式 `Enabled=false`

## 5. 验证

- [ ] 5.1 确认 Urban 抓拍与 LPR 均落到 `Lpr/{yyyy}/{MM}/{dd}/`；清理逻辑对测试目录生效
- [ ] 5.2 确认三产品宿主启动路径均可加载到 ImageCleanup Worker（Common 统一注册）
- [ ] 5.3 `openspec validate fix-lpr-dated-path-and-image-cleanup --strict`
