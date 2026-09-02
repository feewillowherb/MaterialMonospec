## Context

Urban 有人值守列表目前只绑称重 DTO（`urban-weighing-list-presentation`）。LPR 配置已有 `LprSiteType`，但 `add-lpr-site-type` 规定识别路径不得分支。卡口/成品抓拍若再走 `WeighingRecord`，会强迫无重量数据进入称重不变量。研究笔记：`docs/2026-08-28-urban-passage-record/`。

## Goals / Non-Goals

**Goals:**

- Urban 独立表持久化进出抓拍；卡口/成品同实体、`PassageSource` 区分。
- 识别到达后按 `LprSiteType` 路由：地磅称重；卡口/成品写进出。
- 全部记录混合表 + 两个专用 tab；右侧只放大图；车牌「无」→ UI「未识别」。
- `UrbanInOutType` / `UrbanSiteType` 创建时从**该 LPR 配置行**快照，不从城管配置读取。

**Non-Goals:**

- 任何上报、Base64 组图、地磅 `lantu/saveRecord` 改动。
- 标准/固废/回收宿主；进出审批/异常流。
- 萧山 JSON 字段名当 C# 属性；`DeviceCode` 表示进出。

## Decisions

### 1. 实体与 Context

`UrbanPassageRecord` 挂 `UrbanDbContext`，独立 Urban migration。无重量列。附件用逻辑 `{Attachment}Id`（或既有附件表 Id 列表字段），**禁止 FK / 导航**。创建用类型归属工厂（如 `UrbanPassageRecord.FromLprCapture(...)`），Service 不逐字段赋值。

**备选**：两张同构表 → 拒绝，列表与查询重复。

### 2. 枚举分工

| 概念 | 类型 | 存在哪 | 用途 |
|------|------|--------|------|
| 点位 | `LprSiteType` | LPR 行 | 地磅/卡口/成品；识别路由 |
| 进出 | `UrbanInOutType` | LPR 行（Urban Add/Edit）；进出记录快照 | Enter/Exit；上报后再映 `deviceID` 01/02 |
| 场地性质 | `UrbanSiteType` | LPR 行（Urban Add/Edit）；进出记录快照 | 工地/消纳 |

`PassageSource` 仅卡口/成品，与 `UrbanSiteType` 不得混用。城管配置 **不再** 保存三模式启用、进出场或场地。

**有效模式（客户端）**：对 Urban LPR 列表做只读投影（命名 `record` + `From*`，不注册 mapper）：存在 `Scale` 行 ⇒ 地磅能力；存在 `Checkpoint` ⇒ 卡口；存在 `FinishedProduct` ⇒ 成品。没有某类点位则不启用该类路径。禁止再读 `ModesJson` 的 enabled。

**备选**：场地仍按模式放城管配置 → 拒绝。三模式开关与 LPR 点位双写 → 拒绝，只留 LPR。

### 3. 识别路由

Urban 识别后处理读取匹配配置的 `LprSiteType`：`Scale` 现有称重；`Checkpoint`/`FinishedProduct` 调 Urban Passage Service 插入，**禁止** `CreateWeighingRecord`。`UrbanInOutType` / `UrbanSiteType` 取自该 LPR 行。非 Urban 产品保持现网（站点已强制地磅）。缺省颜色「无」、车型「大车」；图 0～2 张有则存。

### 3b. 城管配置与 AddLpr

城管配置面板去掉：三模式启用、地磅/卡口/成品进出场与场地。Urban `AddLprDialog` 增加进出场、场地；点位仍为 `LprSiteType`。JSON 挂在该 `LicensePlateRecognitionConfig` 行，缺省进出 `Enter`、场地 `Construction`。保存用类型归属方法，禁止 mapper Service。

`ModesJson` 若仍随 `UrbanSettingsJson` 残留，加载时 **忽略** enabled / inOut / siteType；不得写回为运行时开关。UrbanManagement 权威信封与上报路径 **本期不改**（不上报）。

### 4. 混合列表

列表行用命名 `record`（如 `UrbanAttendedListRow`），`Kind`：`Weighing` / `Checkpoint` / `FinishedProduct`。称重字段从现网列表 DTO 投影；进出行 `FromUrbanPassageRecord`。ViewModel 只调 Service，禁止 Repository。

分页：同一时间/搜索条件下分别查询两源，按时间降序 merge 后 Skip/Take。站点量级可内存 merge；若单页窗口过大再改为 keyset（本期不强制）。

正常/异常 tab 仍只称重查询（`IsAnomaly`）。卡口/成品 tab 只查 `PassageSource`。

### 5. 照片 UI

入库可存小图+大图。全部表与专用 tab 右侧 **只绑定大图槽**；无大图则空，不回退展示小图。

### 6. 车牌展示

持久化未识别为「无」。投影到列表车牌列时映射为「未识别」。颜色列可显示「无」。

## Risks / Trade-offs

- [混合分页不准] → 两源同过滤后 merge；避免各取一页再拼导致时间交错错误。
- [SQLITE_BUSY] → 写进出走 Urban UoW；与内核同库时遵循 ExistingConnection 既有约定。
- [与旧 lpr-site-type 冲突] → 本 change **MODIFIED** 该能力，去掉「无运行时语义」。

## Migration Plan

Urban 增加进出表；LPR JSON 增加进出/场地。客户端忽略旧 `ModesJson` 三模式与进出/场地键。回滚：删表；LPR 忽略新字段（不作为本期目标恢复城管三模式 UI）。

## Open Questions

无（调研 04 已决）。
