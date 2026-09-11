## Why

UrbanManagement 卡口进出与成品进出列表已具备重置同步，但缺少与称重记录页对齐的「查看照片」入口，也未展示同步时间与同步状态徽章样式，操作员无法在 UM 侧核对抓拍图与 Gov 同步结果。

## What Changes

- 卡口进出（`CheckpointPassage.razor`）与成品进出（`FinishedProductPassage.razor`）操作列增加「查看照片」，弹出对话框展示该行大图（无图时明确空态）。
- 两页列表增加「同步时间」列；「同步状态」改为与称重记录页一致的徽章文案/样式（待同步 / 同步成功 / 同步失败）。
- 保留既有「重置同步」行为与 TEMP 规则；本 change **不**引入称重页的「修改历史」或异常原因列。

## Capabilities

### New Capabilities

- `urban-passage-um-list-ui`: UM Blazor 卡口/成品进出列表的照片查看与同步展示契约（对齐称重列表的同步信息呈现，不含称重特有异常/修改历史）。

### Modified Capabilities

（无）

## Impact

- **仓库**：`repos/UrbanManagement`（`UrbanManagement.App` 页面与可选共享对话框组件；列表 DTO 已含 `LargeImageBase64` / `SyncTime` / `SyncType`，预期以 UI 为主）
- **不涉及**：MaterialClient、Gov Worker、Receive API 契约变更
