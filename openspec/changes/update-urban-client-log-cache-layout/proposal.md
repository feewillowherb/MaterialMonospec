## Why

当前服务端日志缓存按 `ClientLogs/{ClientId}/...` 落盘，运维无法按项目（ProName）快速定位；拉取过程中的文件级失败只写日志或笼统显示成功数，页面上缺少可读错误；已缓存区也是扁平文件表，不能按目录单击展开查看。

## What Changes

- **BREAKING（磁盘布局）**：缓存根目录改为 `ClientLogs/{ProName}/{ClientId}/{相对路径}/{文件名}`；一级目录为项目名（ProName），二级为 ClientId。
- 拉取/写入路径解析统一使用注册能力中的 ProName；ProName 为空或非法字符时使用可预测的安全回退名，避免写盘失败。
- 拉取 API 返回结构化失败明细（文件名 + 原因）；`ClientLogs.razor` 在页面中展示汇总与逐条错误，不再只显示成功计数。
- 已缓存区改为可浏览目录视图：按 ProName → ClientId → 日期子目录展开；单击目录打开查看其下内容，文件仍可下载/删除。
- `GetCachedLogsAsync` / DTO / 扫描逻辑适配新布局，并兼容读取遗留 `ClientLogs/{ClientId}/...` 数据（只读兼容，新拉取只写新布局）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `server-log-pull-api`: 缓存目录布局改为 ProName/ClientId；拉取结果携带失败明细；缓存扫描与下载路径适配新布局并兼容旧目录。
- `client-log-view-page`: 页面展示拉取错误明细；已缓存区支持目录单击展开查看。

## Impact

- **仓库**：UrbanManagement（`ClientLogAppService`、相关 DTO、`ClientLogs.razor`、静态 `/ClientLogs` 映射行为不变但物理子路径变化）
- **API**：`PullAndCacheAsync` / `PullLogsByDateAsync` 返回形状扩展（失败明细）；`CachedLogFileDto` 增加 ProName（或等价字段）以支撑目录视图
- **兼容**：已存在于旧路径下的缓存文件仍可列出与下载；新拉取不再写入旧路径
- **客户端**：MaterialClient 无需改协议；继续上报 ProName 供服务端组路径
- **运维**：服务器磁盘上按项目分文件夹，便于人工排查
