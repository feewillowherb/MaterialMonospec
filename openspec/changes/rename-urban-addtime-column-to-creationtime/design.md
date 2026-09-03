## Context

F3 已把实体审计时间收到 ABP `IHasCreationTime` / `CreationTime`。四张老表仍 `HasColumnName("AddTime")`：`GovProjects`、`GovSyncData`、`UrbanWeighingRecords`、`AttachmentFiles`。`UrbanPassageRecords` 建表即为 `CreationTime`。输出 DTO 仍暴露 `AddTime`（注释写明来自 `CreationTime`）。列表查询已 `OrderByDescending(CreationTime)`。

本 change 为 Mode A，仅 UrbanManagement；与 `rename-urban-entity-buildlicenseno-to-accesscode` 独立。

## Goals / Non-Goals

**Goals:**

- 四表物理列名为 `CreationTime`；去掉 `HasColumnName("AddTime")`。
- 称重索引不再使用 `IX_UrbanWeighingRecords_AddTime` 别名。
- 输出 DTO 属性与 JSON 与实体对齐为 `CreationTime` / `creationTime`。

**Non-Goals:**

- MaterialClient `IMaterialClientAuditedObject.AddTime`（unix int）。
- 改历史 migration 文件正文。
- 改萧山/JWT/Hub wire。
- 改 Blazor 表格列（当前不展示入库时间）。

## Decisions

### 1. 列与 DTO 一并改名（不用继续 HasColumnName）

- **选择**：`RenameColumn` + 默认列名 `CreationTime`；DTO `AddTime` → `CreationTime`。
- **替代**：只改列、DTO 仍叫 `AddTime` —— 否决；与「不要再用 AddTime」不符，且注释已承认 DTO 是别名。
- **理由**：入库时间不是对外政府协议键；消费者主要是 UM 自己的列表 API。

### 2. 手写 RenameColumn + RenameIndex

- **选择**：显式 rename 四列；称重 `IX_UrbanWeighingRecords_AddTime` → `IX_UrbanWeighingRecords_CreationTime`（或删自定义名让 EF 默认）。
- **替代**：EF scaffold —— 否决（与 AccessCode 同样避免启发式）。

### 3. Passage 表不动

- **选择**：`UrbanPassageRecords` / 附件关联表已是 `CreationTime`，migration 跳过。
- **理由**：对已是目标名的列 `RenameColumn` 会失败。

### 4. Git Mode A

- **选择**：分支名 = change 名，自 UrbanManagement trunk 切出。

## Risks / Trade-offs

- **[Risk] 外部 SQL 仍写 AddTime** → 发布说明列出四表；pipeline 对副本验证列名。
- **[Risk] HTTP 客户端读 `addTime`** → **BREAKING** JSON；同仓 Blazor 不展示该字段。若发现外部消费者，需同步改客户端（本 change 不含 MC）。
- **[Risk] 动态 Sorting 字符串 `AddTime desc`** → AppService 默认已按 `CreationTime`；更新 `site.js` 示例注释。
- **[Trade-off] 列表 API JSON 破坏兼容** → 换干净命名；不保留 `[JsonPropertyName("addTime")]`。

## Migration Plan

1. 部署含新 migration 的 UrbanManagement；启动 `MigrateAsync`。
2. 确认四表列为 `CreationTime`、称重行数未丢；`GET` 列表 JSON 含 `creationTime`。
3. 回滚：反向 `RenameColumn` `CreationTime` → `AddTime` 并恢复索引名。

## Open Questions

（无。MaterialClient 审计字段另开 change。）
