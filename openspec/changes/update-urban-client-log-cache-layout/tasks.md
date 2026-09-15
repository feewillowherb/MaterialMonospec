## 1. 路径与拉取结果模型（UrbanManagement）

- [x] 1.1 新增命名 record：`PullLogFileFailure`、`PullAndCacheResult`；扩展 `PullLogsByDateResult`（含 `ProjectName`、`Failures`）；禁止 tuple
- [x] 1.2 `CachedLogFileDto` 增加 `ProjectName`；新增浏览用 DTO/`record`（目录/文件条目、相对路径输入）
- [x] 1.3 实现 `SafeProName` 规范化（非法字符替换；空回退 `_unknown`），并从 `LogCapabilityRegistration` 按 ClientId 解析 ProName
- [x] 1.4 将 `PullAndCacheAsync` / `SaveCachedFileAsync` 写盘路径改为 `ClientLogs/{SafeProName}/{ClientId}/...`
- [x] 1.5 `PullAndCacheAsync` 改为返回 `PullAndCacheResult`；超时与客户端错误写入可区分的 `Failures.Reason`
- [x] 1.6 `PullLogsByDateAsync` 透传 `ProjectName` 与 `Failures`；更新 `IClientLogAppService` 签名

## 2. 缓存扫描与目录浏览 API

- [x] 2.1 更新 `GetCachedLogsAsync`：扫描新布局与遗留 `{ClientId}/...`，填充 `ProjectName`
- [x] 2.2 实现 `BrowseCachedDirectoryAsync`：按相对路径只列一层；根目录区分 ProName 与 `_legacy`
- [x] 2.3 浏览到文件时写入 `PathMap`（确定性 Guid）；批量 ZIP 条目改为 `{ProName}/{ClientId}/...`（遗留用 `_legacy/...`）

## 3. ClientLogs 页面

- [x] 3.1 一键拉取 / 选择性拉取改用新结果类型；页面 alert 展示汇总与逐条失败原因
- [x] 3.2 已缓存区改为目录浏览：面包屑、单击进入、返回上级；调用 `BrowseCachedDirectoryAsync`
- [x] 3.3 文件层保留下载/删除（及既有批量能力若适用）；拉取成功后刷新当前目录视图

## 4. 验证

- [x] 4.1 手动验证：新拉取落在 `ProName/ClientId`；部分失败时页面可见错误原因；目录可单击下钻；遗留缓存仍可浏览下载
- [x] 4.2 `openspec validate update-urban-client-log-cache-layout --strict`
