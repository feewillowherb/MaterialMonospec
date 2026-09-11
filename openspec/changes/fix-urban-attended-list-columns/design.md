## Context

Urban 主窗 `UrbanAttendedWeighingWindow` 对混合/地磅页签与卡口/成品页签使用两套表头，但 `ListBox` 行模板只有称重布局（`ColumnDefinitions="72,96,74,56,126,88,*"`）。卡口/成品页签下表头与行错位：场地列显示 `SortTime`，抓拍时间列显示 `StatusText`（恒为「—」）；`PlateColor` / `VehicleType` / `SiteTypeText` 已在 `UrbanAttendedListRow.FromPassage` 赋值却未绑定。

既有 spec `urban-weighing-list-presentation` 已要求列表展示上传时间，但 AXAML 未绑定 `UploadTime`。地磅行 `FromWeighing` 将 `InOutText` 固定为「—」，`UrbanWeighingExtension` 未持久化 `UrbanInOutType`。

## Goals / Non-Goals

**Goals:**

- 卡口/成品专用行模板与表头 1:1 对齐并绑定正确字段。
- 全页签时间列统一命名「抓拍时间」；新增「上传时间」列并绑定。
- 地磅进出在有可解析来源时展示；passage 上云成功后有上传时间可展示。

**Non-Goals:**

- 不改 UrbanManagement Receive/列表 API 或 Blazor 页。
- 不改 Gov 出站 / govsync Graph。
- 不把技术债务式整表 DataGrid 化；仍用现有 `ListBox` 自定义行。
- 不为历史地磅行回填进出（无来源则保持「—」）。

## Decisions

### D1 — 专用页签使用独立行 `Grid`，不复用称重列定义

- **选择**：在 `ItemTemplate` 增加 `IsVisible` 受父级 `IsPassageDedicatedTab`（或行级等价标志）控制的第三套 `Grid`，列定义为 `96,72,72,56,72,126[,上传时间列]`，绑定 `DisplayPlate`、`PlateColor`、`VehicleType`、`InOutText`、`SiteTypeText`、`SortTime`、`UploadTime`。
- **备选**：仅改绑定顺序仍用称重列宽 — 列宽与表头仍不对齐，否决。
- **备选**：按 `Kind` 在行内切换两套模板但不看 Tab — 在「全部记录」混排时仍要称重列，专用模板仅在卡口/成品 Tab 启用。

实现注意：行模板的 `DataContext` 是 `UrbanAttendedListRow`，不直接有 `IsPassageDedicatedTab`。用以下之一：

1. `RelativeSource` / 命名元素绑定到 Window `DataContext.IsPassageDedicatedTab`；或
2. ViewModel 在 Reload 时给行打 `UseDedicatedPassageColumns` 标志（同一 Tab 内全部为 true）。

优先 (1)，避免污染 DTO。

### D2 — 混合/地磅表头：「时间」→「抓拍时间」，并加「上传时间」

- 混合列保持：类型 | 车牌 | 重量 | 进出 | 抓拍时间 | 上传时间 | 状态 | 操作。
- 地磅 `SortTime` = `AddDate`（称重发生时间，界面仍标「抓拍时间」以统一用词；不另开「称重时间」列）。
- `UploadTime` 已有：扩展 `SyncStatus == Synced` 时用 `UpdateDate ?? AddDate`；无值显示「—」。

### D3 — Passage 上传时间：实体方法写入 `UploadedAt`

- **选择**：`UrbanPassageRecord` 增加可空 `UploadedAt`；`MarkSynced()`（或等价类型归属方法）在标记同步成功时写入当前时间；`FromPassage` 映射到 `UploadTime`。
- **备选**：复用无字段、列表侧恒「—」— 无法满足「所有页面」上传时间，否决。
- **备选**：用 `IHasModificationTime` 通用 UpdateTime — 与任意编辑混淆，否决。

遵守 `type-owned-methods`：Service 不逐字段赋 `UploadedAt`。

### D4 — 地磅进出：扩展上持久化 `UrbanInOutType?`

- **选择**：`UrbanWeighingExtension` 增加可空 `UrbanInOutType`；在 LPR/地磅侧写扩展时，从触发设备的 `LicensePlateRecognitionConfig.UrbanInOutType` 经类型归属方法写入；列表投影到 `InOutText`（进/出），空则「—」。
- **备选**：列表时按车牌反查最近卡口记录 — 脆弱且跨实体猜，否决。
- **备选**：正常/异常 Tab 隐藏进出列 — 与「应显示进出」诉求不符，否决。

历史行无值保持「—」，不强制回填 migration data。

### D5 — 列宽微调

上传时间加入后，混合与专用两套 `ColumnDefinitions` 一并加一列（建议 `126` 宽、格式 `yyyy-MM-dd HH:mm`），避免挤掉操作/审批列。

## Risks / Trade-offs

- [卡口/成品行可见性绑定失败] → 用命名 Root + `DataContext` 相对绑定；DevTools 核对 `IsPassageDedicatedTab`。
- [地磅进出仍大量「—」] → 仅新产生且带 LPR 配置的记录有值；在 report/验收说明中写明。
- [SQLite migration] → Urban DbContext 增量 migration；无引擎 FK；失败则应用无法启动，需本地验证 `.build-verify`。

## Migration Plan

1. 加列 / migration → 投影 UploadTime / InOut → AXAML 表头与行模板 → 手动点五个 Tab 验收。
2. 回滚：还原 migration 与 UI；无服务端契约变更。

## Open Questions

- 无（地磅「抓拍时间」实际为称重 `AddDate` 的用词统一已在 D2 拍板；若产品后续要拆「称重时间」另开 change）。
