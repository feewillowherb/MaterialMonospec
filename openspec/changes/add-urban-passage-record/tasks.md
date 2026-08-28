## 1. Persistence

- [x] 1.1 Add `UrbanPassageRecord` (and `PassageSource` enum) on `UrbanDbContext` with snapshot `UrbanInOutType` / `UrbanSiteType`, plate fields, `CapturedAt`, logical attachment ids; no weight, no FK, no navigations
- [x] 1.2 Add type-owned factory (e.g. `FromLprCapture`) for create; Service MUST NOT assign entity fields
- [x] 1.3 Add Urban EF migration for the new table

## 2. Application service

- [x] 2.1 Add Urban passage Service with `[UnitOfWork]` writes, Repository + `UrbanDbContext` only (no ViewModel injection)
- [x] 2.2 Add paged query APIs using named input/result records (no tuples): by `PassageSource`; mixed merge with weighing list under the same time/search filters then Skip/Take
- [x] 2.3 Project list rows with destination `From*` (shared attended list row); map stored plate「无」to display「未识别」

## 3. LPR routing

- [x] 3.1 Urban recognition persistence: `LprSiteType.Scale` existing weighing; `Checkpoint` / `FinishedProduct` insert passage only
- [x] 3.2 Snapshot `UrbanInOutType` and `UrbanSiteType` from the matched LPR row (not 城管配置); default color「无」、vehicle「大车」; persist 0–2 images without padding

## 4. Settings UI

- [x] 4.1 Urban Add/Edit LPR: add 进出场 and 场地; persist on `LicensePlateRecognitionConfig` via type-owned methods; defaults 进 / 工地
- [x] 4.2 Remove 三模式启用、进出场、场地 from 城管配置; stop using `ModesJson` enabled/inOut/siteType as runtime; derive capabilities from LPR `LprSiteType` via `From*` on a named record
- [x] 4.3 Non-Urban AddLpr MUST NOT show or require 场地/进出场

## 5. Urban attended UI

- [x] 5.1 Add 卡口 / 成品 tabs with dedicated columns from `specs/urban-passage-record`
- [x] 5.2 Change「全部记录」to mixed columns from `specs/urban-weighing-list-presentation`; keep 正常/异常 weighing-only
- [x] 5.3 Right-side photo: large image only for weighing and passage; hide small image
- [x] 5.4 Passage rows: no approve; weighing rows keep existing anomaly approve rules
- [x] 5.5 ViewModel calls Service only; `ListItems` is one collection of the shared row type

## 6. Verify

- [x] 6.1 Tests or equivalent for factory defaults, routing (scale vs checkpoint), plate display mapping, LPR JSON defaults
- [x] 6.2 Confirm no Xiaoshan/upload calls on passage create
- [x] 6.3 `openspec validate add-urban-passage-record --strict`
