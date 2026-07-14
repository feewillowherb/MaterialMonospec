## Context

Camera（枪机）抓拍已通过 `AttachmentPathUtils.GetLocalStorageAbsolutePath` 落到 `{PhotoJianKong|PhotoUrban}/{yyyy}/{MM}/{dd}/`。LPR 在 `HikvisionLprService` / `VzvisionLprService` 中仍用扁平 `Lpr/`。现场希望 Urban 枪机与 LPR 共用同一磁盘根，便于运维与统一清理。

各客户端已有 ABP `AsyncPeriodicBackgroundWorkerBase` 模式，可由 `BackgroundServices:*` 控制注册。

## Goals / Non-Goals

**Goals:**

- LPR 落盘：`Lpr/{yyyy}/{MM}/{dd}/…`。
- `UrbanPhoto` 与 `Lpr` 共用根目录 `Lpr`（日期目录同构）；`AttachType` 仍区分业务类型。
- 可配置后台任务清理过期 `PhotoJianKong` + `Lpr`（及历史 `PhotoUrban`）。
- **所有产品客户端**具备同一清理能力（Standard/SolidWaste、Urban、Recycle）；默认启用。
- 配置：启用、保留天数、间隔、首选钟点。

**Non-Goals:**

- 不迁移历史文件到新位置。
- 不删 / 改 DB `AttachmentFile` 行。
- 不清理 `PhotoPiaoJu`、`LprDebug`。
- 不改服务端 UrbanManagement 存储布局。
- 不实现 UI 设置页。
- 不强制 Toolkit 等非称重产品入口开启清理（可用配置关闭）。

## Decisions

### D1 — LPR 落盘复用 AttachmentPathUtils

- **选择**：`AttachmentPathUtils.GetLocalStorageAbsolutePath(AttachType.Lpr)` + 确保目录存在。
- **理由**：与枪机共用日期段逻辑，避免手写路径漂移。

### D2 — UrbanPhoto 根路径改为 Lpr

- **选择**：`GetBasePath(AttachType.UrbanPhoto)` 从 `"PhotoUrban"` 改为 `"Lpr"`（与 `AttachType.Lpr` 相同）。
- **理由**：Urban 枪机与车牌图同目录树，清理与排障只盯一个根；OSS object key / 相对路径随根变化一并落在 `Lpr/...`。
- **不变**：`AttachType.UrbanPhoto` 枚举与挂接语义不变；UI / 同步仍按类型过滤。
- **替代**：继续写 `PhotoUrban` — 拒绝（与本次需求冲突）。

### D3 — 清理根目录范围

| 根目录 | 含义 |
|--------|------|
| `PhotoJianKong` | 非 Urban 枪机（EntryPhoto 等） |
| `Lpr` | LPR + 新 UrbanPhoto |
| `PhotoUrban` | **仅兼容清理历史文件**；新写入不再使用 |

- 保留判定：优先 `{root}/{yyyy}/{MM}/{dd}` 目录日；无法解析则 `LastWriteTime`（扁平旧 `Lpr/*.jpg`）。
- 尽力删除空目录。

### D4 — 配置契约（appsettings.json）

```json
"BackgroundServices": {
  "ImageCleanup": {
    "Enabled": true,
    "RetentionDays": 90,
    "IntervalHours": 24,
    "PreferredStartHour": 3
  }
}
```

绑定 `ImageCleanupOptions`，section：`BackgroundServices:ImageCleanup`。

### D5 — Worker 放置与注册（全客户端统一）

- **决策**：清理服务 `ILocalImageCleanupService` **与** `ImageCleanupBackgroundService`（`AsyncPeriodicBackgroundWorkerBase`）均放在 **MaterialClient.Common**；在 `MaterialClientCommonModule` 的应用初始化中按 `BackgroundServices:ImageCleanup:Enabled` 调用 `AddBackgroundWorkerAsync` **一次注册**。
- **理由**：Standard / Urban / Recycle（及未来新产品宿主）都依赖 Common，统一注册可保证「所有产品客户端都有清理」，避免在各宿主漏挂。
- **依赖**：Common 增加 `Volo.Abp.BackgroundWorkers`（或项目已有等价包引用）。
- **替代（拒绝）**：仅在 Urban 或个别宿主注册 — 与「全客户端」冲突；三宿主各写一份薄壳 — 易漂移且易漏。
- **Toolkit**：亦依赖 Common；若完整启动 ABP 会带着 Worker。Toolkit 的 `appsettings` 可将 `Enabled` 设为 `false`，或接受短生命周期下无实质影响。

### D6 — 执行安全

- 单文件失败 Warning 继续；`RetentionDays < 1` 跳过并 Warning。

## Risks / Trade-offs

- [UrbanPhoto 与 Lpr 文件混在同目录] → 靠文件名约定与 DB `AttachType` 区分；可接受。
- [历史 PhotoUrban 残留] → 清理任务继续扫 `PhotoUrban`；不强制迁移。
- [OSS key 根从 PhotoUrban 变为 Lpr] → 新上传路径变更；旧已同步对象不改。
- [并发删文件] → 跳过失败，不阻塞称重。

## Migration Plan

1. 发版：新 UrbanPhoto / LPR 均写 `Lpr/{yyyy}/{MM}/{dd}/`。
2. 默认启用清理；兼容删旧 `PhotoUrban` 与扁平 `Lpr`。
3. 无 DB migration。
4. 回滚需发版改回 `GetBasePath`；配置仅能关清理。

## Open Questions

- 无。
