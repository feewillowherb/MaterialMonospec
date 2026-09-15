## ADDED Requirements

### Requirement: 按 ProName 与 ClientId 组织缓存目录

服务端写入客户端日志缓存时，一级目录 MUST 使用项目名（ProName），二级目录 MUST 使用 ClientId。

#### Scenario: 新拉取写入 ProName/ClientId 路径

- **假设** 客户端 `material-client-001` 已注册日志能力且 `ProName` 为 `萧山项目A`
- **WHEN** `PullAndCacheAsync` 成功保存文件 `app.log`，相对 `FilePath` 为 `2025/06/22`
- **THEN** 系统 SHALL 将文件写入 `ClientLogs/{SafeProName}/material-client-001/2025/06/22/app.log`
- **AND** `SafeProName` SHALL 为对 ProName 做文件系统非法字符替换后的安全目录名

#### Scenario: ProName 为空时回退目录名

- **假设** 客户端在线但注册的 `ProName` 为空或仅含非法字符
- **WHEN** 拉取并缓存日志文件
- **THEN** 系统 SHALL 使用回退目录名 `_unknown` 作为一级目录
- **AND** 二级目录仍为该客户端的 `ClientId`

#### Scenario: SaveCachedFile 使用相同布局

- **假设** 调用 `SaveCachedFileAsync` 且客户端已注册 `ProName`
- **WHEN** 保存文件
- **THEN** 系统 SHALL 写入 `ClientLogs/{SafeProName}/{ClientId}/{FilePath}/{FileName}`
- **AND** 更新路径映射供后续下载/删除

### Requirement: 拉取结果包含失败明细

拉取 API MUST 返回结构化成功与失败信息，供页面展示错误原因。

#### Scenario: 部分文件拉取失败返回 Failures

- **假设** 请求拉取 3 个文件，其中 1 个传输超时、1 个客户端报错、1 个成功
- **WHEN** `PullAndCacheAsync` 完成
- **THEN** 系统 SHALL 返回命名 `record` 结果（禁止使用 tuple），包含已成功路径列表与 `Failures`
- **AND** 每个失败项 SHALL 包含 `FileName`、`FilePath`、`Reason`
- **AND** 超时与客户端报错的 `Reason` SHALL 可区分
- **AND** 不因单个文件失败而中断其余文件拉取

#### Scenario: 按日期拉取透传失败明细

- **WHEN** `PullLogsByDateAsync` 完成且存在失败文件
- **THEN** 返回的 `PullLogsByDateResult` SHALL 包含 `ProjectName`、`PulledCount`、`PulledFiles` 与 `Failures`
- **AND** `Failures` SHALL 与底层 `PullAndCacheAsync` 失败列表一致

### Requirement: 已缓存目录浏览 API

服务端 MUST 提供按相对路径列举已缓存子目录与文件的能力，以支持页面单击下钻查看。

#### Scenario: 浏览根目录列出项目文件夹

- **假设** 磁盘存在 `ClientLogs/萧山项目A/client-1/...` 与遗留路径 `ClientLogs/old-client/...`
- **WHEN** 调用浏览 API 且相对路径为空（根）
- **THEN** 系统 SHALL 返回项目目录条目（来自新布局一级目录）
- **AND** 遗留一层 ClientId 目录 SHALL 归入可识别的遗留入口（如 `_legacy`），不得与真实 ProName 混淆

#### Scenario: 单击进入 ProName 后列出 ClientId

- **假设** 当前相对路径为某 `SafeProName`
- **WHEN** 调用浏览 API
- **THEN** 系统 SHALL 仅列举该目录下一层的 ClientId 子目录（及该层直接文件，若有）
- **AND** 不得递归扫描全部深层文件

#### Scenario: 进入 ClientId 后列出日期或文件

- **假设** 当前相对路径为 `{SafeProName}/{ClientId}`
- **WHEN** 调用浏览 API
- **THEN** 系统 SHALL 返回该层子目录（如 `yyyy` 或日期段）与可下载的文件条目
- **AND** 文件条目 SHALL 带确定性 Guid 并写入路径映射，以便下载/删除

#### Scenario: GetCachedLogs 适配新布局字段

- **WHEN** 调用 `GetCachedLogsAsync`
- **THEN** 系统 SHALL 能扫描新布局与遗留布局下的 `.log` 文件
- **AND** 每个 `CachedLogFileDto` SHALL 填充 `ClientId` 与 `ProjectName`（遗留布局 `ProjectName` 可为空或 `_legacy`）
- **AND** 仍按修改时间降序分页

## MODIFIED Requirements

### Requirement: 服务端主动拉取日志（由 UI 触发）

服务端 MUST 提供由管理员在 UI 中触发的主动拉取能力，服务端直接通过 SignalR 从客户端拉取日志文件并写入磁盘，浏览器不参与文件传输。缓存路径一级 SHALL 为 ProName、二级 SHALL 为 ClientId。

#### Scenario: 一键拉取指定日期全部日志

- **假设** 管理员在 `ClientLogs.razor` 页面选择了客户端 "material-client-001" 和日期 "2025/06/22/"，且该客户端 `ProName` 为 "萧山项目A"
- **WHEN** 管理员点击"拉取到服务器"按钮
- **THEN** 系统 SHALL 调用 `PullLogsByDateAsync(clientId, dateFolder)`
- **AND** 服务端首先通过 `RequestLogListAsync` 查询该日期的日志文件列表
- **AND** 对每个文件通过 `IHubContext` 发送 `ReceiveFileContentRequest` 到客户端
- **AND** 客户端返回的文件分块通过服务端回调写入 `MemoryStream`
- **AND** 文件传输完成后直接写入 `ClientLogs/{SafeProName}/{ClientId}/{Date}/{FileName}` 磁盘目录
- **AND** 返回 `PullLogsByDateResult`，包含 `ProjectName`、`TotalFilesFound`、`PulledCount`、`PulledFiles`、`Failures`
- **AND** 页面显示拉取结果（含失败明细）并刷新已缓存目录视图
- **AND** 数据路径为 Client → DeviceStatusHub → AppService → 磁盘（无浏览器中转）

#### Scenario: 一键拉取时客户端离线

- **假设** 客户端未注册或已离线
- **WHEN** 调用 `PullLogsByDateAsync`
- **THEN** 系统 SHALL 在 `RequestLogListAsync` 阶段抛出 `UserFriendlyException`
- **AND** 页面显示错误提示"客户端未注册日志拉取能力"

#### Scenario: 一键拉取时无日志文件

- **假设** 指定日期无日志文件
- **WHEN** `PullLogsByDateAsync` 查询到 0 个文件
- **THEN** 系统 SHALL 返回 `PullLogsByDateResult`，`TotalFilesFound` 为 0
- **AND** 页面显示"该日期无日志文件"

#### Scenario: 选择性拉取指定文件

- **假设** 管理员已查询日志列表并选中 2 个文件，客户端已注册 ProName
- **WHEN** 管理员点击"拉取并缓存"按钮
- **THEN** 系统 SHALL 调用 `PullAndCacheAsync(new PullLogDto { ClientId, Files })`
- **AND** 服务端通过 `IHubContext` 逐文件发送 `ReceiveFileContentRequest`
- **AND** 文件分块直接写入 `ClientLogs/{SafeProName}/{ClientId}/...`
- **AND** 返回结构化结果（含 `Failures`）
- **AND** 页面显示拉取结果并刷新已缓存目录视图
