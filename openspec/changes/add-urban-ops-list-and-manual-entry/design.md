## Context

称重列表已有「施工单位 / 项目 / 同步时间 / 查看照片」；卡口与成品进出页目前仅车牌等字段 + 同步状态文案，无施工单位/项目、无照片、无同步时间。异常审批可按是否异常筛选，但不能按 `AnomalyReason`。项目管理无 Web 端人工补录。图片组件（`WeighingPhotoPreview` / 审批预览）以 Lrp+UrbanPhoto 双槽、每类型首张为主，缺少多图浏览与左击大图。活动 change `update-urban-passage-um-list-photo-sync` 仅覆盖照片+同步时间且未 apply，本 change 一并吸收并扩展列。

## Goals / Non-Goals

**Goals:**

- 项目管理「添加」→ 人工称重录入；`AnomalyReason = "人工录入"`；默认自动入政府同步队列
- 异常审批：异常原因下拉过滤
- 卡口/成品：列 1=施工单位、列 2=项目；照片查看；同步时间 + 徽章对齐称重
- 共享多图 + 左击 lightbox（称重/审批/卡口/成品）

**Non-Goals:**

- MaterialClient 桌面补录 UI
- 改造 Gov 报文字段映射（人工录入仍走现有 Xiaoshan/Gov 管道）
- 删除 passage「重置同步」TEMP 行为（可保留）

## Decisions

### D1: 人工录入与自动上传

**选择**：创建 `UrbanWeighingRecord`，`AnomalyReason = "人工录入"`，`IsAnomaly = true`（便于异常审批与原因过滤）；GovSync **白名单**：当 `AnomalyReason` 等于「人工录入」时 **允许** 进入同步（覆盖「异常一律不同步」）；表单默认勾选/默认启用自动上传（`SyncType=Pending`）。若关闭自动上传，则保持 Pending 但可由产品决定是否暂不入队（默认开启）。

**备选否决**：`IsAnomaly=false` 仅写 Reason——异常审批过滤「人工录入」会漏。

### D2: 施工单位 / 项目列语义

对齐称重页：

| 列 | 来源 |
|----|------|
| 施工单位 | `GovProject.ShigongUnitName`（按 `ProId` 查表，无则 `-`） |
| 项目 | `UrbanPassageRecord.ProName`（无则 `-`） |

列表 DTO 可直接带出 `ProName`；施工单位可在 AppService 二次查询项目表组合（无 DB FK）。列顺序：**必须为表头前两列**。

### D3: 吸收 passage photo-sync change

本 change 的 `urban-passage-um-list-ui` delta **包含**照片对话框、同步时间、徽章；旧 change 视为 superseded，不再并行 apply。

### D4: 多图 + 左击大图

共享 lightbox 组件：输入有序图片 URL/base64 列表；缩略图区展示全部；左键单击打开全屏/模态大图（可 Esc/关闭按钮）。称重 Lrp/UrbanPhoto 若同类型多附件则全部进入列表；passage 大图若仅一张则单元素列表仍可用同一组件。

### D5: 异常原因过滤选项

下拉：「全部」+ 当前库中出现过的 distinct `AnomalyReason`（至少保证「人工录入」可选，即使尚无数据也可静态加入）。`GetListAsync` 增加 `AnomalyReason` 精确匹配过滤。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 人工录入既是异常又可同步，易误解 | UI 标明来源；spec 明确 GovSync 白名单 |
| AnomalyReason 长度 32 | 「人工录入」4 字；常量集中 |
| 列表二次查 ShigongUnitName 性能 | 按页 ProId 批量查 GovProject |
| 与旧 passage change 双轨 | proposal 声明 supersede |

## Migration Plan

1. 部署 UM；无需破坏性 migration（DTO/UI 为主；人工录入用现有表）
2. 关闭/归档空实现的 `update-urban-passage-um-list-photo-sync`
3. 回滚：隐藏「添加」与新列/过滤；恢复 GovSync 跳过全部异常

## Open Questions

- 无（自动上传默认开；白名单仅「人工录入」字面量）
