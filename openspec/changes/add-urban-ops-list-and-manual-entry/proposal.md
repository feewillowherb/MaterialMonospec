## Why

运营侧在 UrbanManagement 控制台仍有多处缺口：项目管理无法人工补录称重、异常审批无法按异常原因筛选、卡口/成品进出列表缺少与称重页对齐的施工单位/项目列与照片/同步时间能力，且各页图片查看不支持多图与左击放大。需要一次补齐控制台录入与列表体验。

## What Changes

- **项目管理**：操作栏新增「添加」，打开人工补录称重表单；创建记录的 `AnomalyReason` 固定为 **人工录入**；默认进入自动上传（政府同步）队列（见 design 对 `IsAnomaly`/GovSync 白名单的约定）
- **异常审批页**：新增异常原因种类下拉过滤（含「全部」与已知原因枚举/去重列表，至少含「人工录入」）
- **卡口进出 / 成品进出**：列表前两列增加 **施工单位**、**项目**（对齐称重列表语义：施工单位←`GovProject.ShigongUnitName`，项目←`ProName`）；补齐「查看照片」与「同步时间」及同步状态徽章样式
- **图片查看（全局）**：称重/审批/卡口/成品等所有图片查看入口支持 **多图**；支持 **鼠标左键点击** 打开大图（lightbox），可关闭返回
- **范围吸收**：本 change **吸收并取代** 活动变更 `update-urban-passage-um-list-photo-sync` 中「卡口/成品照片 + 同步时间」的未实施范围，避免双轨；apply 时以本 change 为准，该旧 change 应关闭/归档空实现或标记 superseded

## Capabilities

### New Capabilities

- `urban-manual-weighing-entry`: 项目管理人工补录称重（人工录入原因 + 默认自动上传）
- `urban-multi-image-lightbox`: UM Blazor 多图预览与左击大图的共享交互契约

### Modified Capabilities

- `blazor-project-management`: 操作栏「添加」入口
- `urbanmanagement-weighing-record-approval`: 异常审批页按 `AnomalyReason` 过滤
- `urban-passage-um-list-ui`: 卡口/成品列表列序（施工单位、项目前两列）、照片、同步时间/徽章（新建于本 change 或延续未归档 delta）
- `urban-weighing-photo-view`: 多图 + 左击大图（不再限「每类型仅首张」）
- `urban-passage-cloud`: 列表列要求补充施工单位/项目（若与现有「Columns MUST include…」冲突则 MODIFIED）

## Impact

- **子仓库**：`repos/UrbanManagement`（`ProjectManagement.razor`、`WeighingApproval.razor`、`CheckpointPassage.razor`、`FinishedProductPassage.razor`、称重/审批照片组件、Passage 列表 DTO、人工录入 AppService API、可选 GovSync 白名单）
- **不涉及**：MaterialClient 协议（除非补录复用既有 Receive DTO，仍仅服务端/Web）
- **分支**：Mode A — `add-urban-ops-list-and-manual-entry`
- **关联**：supersede `update-urban-passage-um-list-photo-sync`
