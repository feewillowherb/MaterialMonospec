## Why

城管现场除地磅称重外，卡口与成品口的车牌识别也要留下进出抓拍，但不能写入带重量的称重流水。`LprSiteType` 已能区分点位，需要据此入库并在 Urban 客户端列表中展示；本期只本地持久化，不上报萧山。

## What Changes

- 在 `UrbanDbContext` 新增无重量实体 `UrbanPassageRecord`：卡口与成品共用一张表，用 `PassageSource` 区分；行上快照 `UrbanInOutType`、`UrbanSiteType`，禁止库 FK。
- **城管配置删除进出场、场地，并删除 ModesJson 三模式启用**：城管配置不再保存或展示地磅/卡口/成品的开关、进出场、场地。是否走地磅称重、卡口进出、成品进出，**只由是否存在对应 `LprSiteType` 的 LPR 行决定**（有地磅点则称重路径可用，有卡口/成品点则写进出记录）。客户端 MUST NOT 再把 `ModesJson` 的 enabled 当作运行时开关。
- **场地改到添加/编辑 LPR**（Urban）：每条 `LicensePlateRecognitionConfig` 增加 `UrbanSiteType`（工地/消纳）。非 Urban 不展示、不持久化该业务字段。
- **进出场不再挂城管配置**：每条 LPR 行保存 `UrbanInOutType`（进/出），在同一 Add/Edit LPR 对话框设置。创建进出记录（及地磅称重需要方向时）快照**该识别设备行**，不读城管配置。
- LPR 识别按配置行 `LprSiteType` 分支：**地磅** 仍走现有称重；**卡口/成品** 创建进出记录，不 `CreateWeighingRecord`。
- Urban 客户端「全部记录」改为称重 + 进出 **一张混合表**（按时间交错）；右侧照片 **只放大图**。新增 **卡口**、**成品** tab，仅展示进出业务列。正常/异常 tab **仍只称重**。
- 未识别车牌库内仍为「无」，列表车牌列显示「未识别」。
- **本期不做** 任何上传（含萧山 `inoutRecord/save`、地磅上云扩展）。
- **BREAKING**（相对 `lpr-site-type`）：站点类型从此具有运行时语义（仅 Urban 卡口/成品识别路径）。

## Capabilities

### New Capabilities

- `urban-passage-record`: Urban 进出记录实体、LPR 创建、附件逻辑 Id、专用 tab 列表列与展示规则。

### Modified Capabilities

- `lpr-site-type`: 撤销「无运行时语义」；卡口/成品识别必须创建进出记录；Urban LPR 行携带场地与进出场；三模式由 LPR 点位集合推导。
- `settings-ui`: Add/Edit LPR 增加场地与进出场；城管配置去掉三模式开关及进出场/场地。
- `xiaoshan-upload-config`: 客户端城管配置不再以 `ModesJson` 为三模式与进出/场地的真源。
- `xiaoshan-upload-modes`: MaterialClient.Urban 不再用城管配置编辑 Weighbridge/Gate/Product 启用。
- `urban-weighing-list-presentation`: 「全部记录」混合行类型、列与操作分叉；正常/异常仍只称重；右侧仅大图。

## Impact

- **MaterialClient.Urban / Common**：`UrbanDbContext` migration、Urban Service + Repository、LPR 识别后处理、attended 列表、`LicensePlateRecognitionConfig` 与 AddLpr、城管配置表单/ModesJson。
- **MaterialClient.Kernel**：不新增称重实体；识别路由读 `LprSiteType` 及该行进出/场地。
- UrbanManagement / BasePlatform / 萧山 HTTP：**无本期变更**。
- 研究笔记：`docs/2026-08-28-urban-passage-record/`。
