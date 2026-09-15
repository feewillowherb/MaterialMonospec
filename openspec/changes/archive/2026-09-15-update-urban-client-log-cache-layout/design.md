## Context

UrbanManagement 客户端日志拉取已落地：`ClientLogAppService` 经 DeviceStatusHub SignalR 拉文件，写入 `{ContentRoot}/ClientLogs/{ClientId}/...`，`ClientLogs.razor` 提供查询/拉取/扁平已缓存表。注册能力已带 `ProName`（UI 下拉显示为 `ProjectName`），但未参与落盘路径。拉取失败时服务端只增加 fail 计数并打日志，API 返回成功路径列表，页面只能显示「成功 N/M」，无法展示失败原因。已缓存区无目录浏览能力。

约束：无 DB 实体（磁盘 + `PathMap`）；禁止 tuple，多值用命名 `record`；本 change 仅 UrbanManagement。

## Goals / Non-Goals

**Goals:**

- 新拉取写入 `ClientLogs/{ProName}/{ClientId}/{相对路径}/{文件名}`
- 拉取失败在页面展示可读错误（汇总 + 逐文件原因），并在服务端应用日志中记录同等失败明细
- 已缓存区支持按目录单击进入查看（ProName → ClientId → 日期/子目录 → 文件）
- 遗留 `ClientLogs/{ClientId}/...` 仍可列出与下载

**Non-Goals:**

- 不批量迁移/搬迁旧目录文件到新布局
- 不改 MaterialClient SignalR 协议或本地日志目录规范
- 不引入 ClientLog 数据库表或审计实体
- 不做服务端在线文本预览编辑器（查看指目录内文件列表与既有下载）
- 不清理 OpenSpec 中与 HTTP `:5900` 相关的历史漂移（除非本 change 触及的 requirement 一并修正）

## Decisions

### D1: 磁盘布局与 ProName 解析

- **选择**：`ClientLogs/{SafeProName}/{ClientId}/{FilePath}/{FileName}`，其中 `SafeProName` 来自 `_logCapabilityRegistry` 的 `ProName`（与 `ClientInfoDto.ProjectName` 同源）。
- **Sanitize**：替换 `Path.GetInvalidFileNameChars()` 与首尾空白；空/全非法时回退 `_unknown`。
- **解析时机**：`PullAndCacheAsync` / `SaveCachedFileAsync` 写盘前按 `ClientId` 查注册表；离线已由现有校验抛错，不另开「无 ProName 仍写入 ClientId 根」分支。
- **备选否决**：仅用 ClientId（现状，无法按项目分文件夹）；仅用 ProName 单层（多客户端同项目会冲突）。

### D2: 拉取结果改为结构化 record（含失败明细）

- **选择**：将 `PullAndCacheAsync` 返回值由 `List<string>` 改为命名 `record`，例如：

```csharp
public record PullLogFileFailure(string FileName, string FilePath, string Reason);

public record PullAndCacheResult(
    string ClientId,
    string ProjectName,
    int RequestedCount,
    IReadOnlyList<string> PulledFiles,
    IReadOnlyList<PullLogFileFailure> Failures);

public record PullLogsByDateResult(
    string ClientId,
    string ProjectName,
    string DateFolder,
    int TotalFilesFound,
    int PulledCount,
    IReadOnlyList<string> PulledFiles,
    IReadOnlyList<PullLogFileFailure> Failures);
```

- 单文件超时 / 客户端 `ReceiveFileError` / 异常均写入 `Failures.Reason`（区分超时与客户端报错，不再一律标 Timeout）。
- UI：成功/部分成功/全失败均用页面 alert；有 `Failures` 时列出「文件名 — 原因」。
- 日志：每个失败项在写入 `Failures` 时 MUST 打服务端 Warning/Error（含 `FileName`、`ClientId`、`Reason`）；批次结束若 `Failures` 非空 MUST 再打一条汇总，列出逐条「文件名 — 原因」，便于与页面对照检索。
- **备选否决**：继续只返回成功路径（页面无法展示错误）；抛异常中断整批（破坏现有部分成功语义）；仅页面展示、不写应用日志（运维无法事后检索）。

### D3: 已缓存目录浏览 API

- **选择**：新增 `BrowseCachedDirectoryAsync(BrowseCachedDirectoryInput)`，返回当前相对路径下的子目录与文件条目（命名 DTO/`record`），支持从根开始单击下钻；保留 `GetCachedLogsAsync` 供兼容/全局扫描，并解析新布局填充 `ProjectName`。
- 相对路径约定：空 = `ClientLogs` 根；一层 = ProName；二层 = ClientId；更深 = 日期或其它子目录。遗留布局在根扫描时作为「无 ProName 的 ClientId 目录」出现（例如挂在 `_legacy` 虚拟节点，或直接以 ClientId 名出现并标记 `IsLegacy`），避免与真实 ProName 混淆。
- UI：面包屑 + 当前目录表格；目录行单击进入；文件行保留下载/删除。
- **备选否决**：仅前端对扁平列表做 group（大目录分页困难）；依赖 OS 资源管理器打开服务器路径（Web 不可达）。

### D4: PathMap 与确定性 Guid

- 继续用相对路径 SHA256 前 16 字节生成 Guid；相对路径含 ProName 段后，新旧文件 Id 自然分离，无需迁移映射。

### D5: ZIP 条目命名

- 批量 ZIP 内路径改为 `{ProName}/{ClientId}/{...}`（遗留文件无 ProName 时用 `_legacy/{ClientId}/...`），便于解压后按项目归档。

## Risks / Trade-offs

- [旧缓存与新布局并存] → 浏览 API 显式兼容遗留一层 ClientId；文档/UI 可用标记区分；不自动搬迁。
- [ProName 变更导致同客户端新目录] → 接受；以注册时当前 ProName 为准；旧路径仍可浏览。
- [ProName 含非法字符或重复 sanitize 碰撞] → sanitize + 日志；极端碰撞概率低，必要时后续加短哈希后缀（本 change 不做）。
- [PullAndCache 返回类型破坏 ABP 自动 API 调用方] → 仓库内仅 `ClientLogs.razor` 与服务自用；同步改调用处。
- [目录浏览深路径性能] → 仅列举当前一层 `EnumerateFileSystemEntries`，不做全树递归。

## Migration Plan

1. 部署含新布局的 UrbanManagement。
2. 新拉取写入 `ProName/ClientId/...`；旧文件仍可读。
3. 回滚：回退代码后新布局文件对旧扫描器可能显示异常（旧代码把 ProName 当成 ClientId）；回滚前避免依赖新路径运维流程，或保留只读兼容补丁。
4. 可选后续 change：一次性搬迁脚本（本 change 不做）。

## Open Questions

- 无（ProName 空回退 `_unknown`、遗留目录以 `_legacy` 虚拟节点呈现，作为默认实现约定）。
