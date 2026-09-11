## Why

Urban 主界面左侧列表在「正常 / 异常 / 卡口 / 成品」等页签上，表头与行模板列错位、时间列命名不统一，且「上传时间」虽已有 DTO 字段却未渲染，导致操作员无法正确读进出、场地与抓拍/上传时间。

## What Changes

- 修正「卡口」「成品」专用表头与行模板列对齐：车牌、车牌颜色、车型、进出、场地、抓拍时间各绑正确字段（含 `SiteTypeText`）。
- 「全部记录 / 正常 / 异常」时间列表头统一为「抓拍时间」；各地磅行继续用称重发生时间（既有 `SortTime`/`AddDate`）展示。
- 所有页签列表新增「上传时间」列，绑定 `UrbanAttendedListRow.UploadTime`；无值显示「—」。
- 卡口/成品行在上云成功后写入并展示上传时间（扩展 passage 同步时间语义）。
- 正常/异常（及混合表中的地磅行）在存在可解析的进出场来源时展示「进/出」，否则保持「—」（补齐写入与列表投影，避免空列永远无值）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-list-presentation`: 专用卡口/成品列绑定契约；时间列命名统一为抓拍时间；上传时间全页签可见；地磅进出有来源时须展示。

## Impact

- **仓库**：`repos/MaterialClient`（`MaterialClient.Urban` 视图、`MaterialClient.Common` 列表 DTO、`MaterialClient.Common.Urban` 扩展/passage 同步时间与进出写入）
- **UI**：`UrbanAttendedWeighingWindow.axaml` 表头与 `ListBox` 行模板
- **数据**：可能为 `UrbanPassageRecord` / `UrbanWeighingExtension` 增加上传或进出相关字段（逻辑 Id，无 DB FK）
- **不涉及**：UrbanManagement 服务端 API、Gov 出站、OpenSpec 外仓业务变更
