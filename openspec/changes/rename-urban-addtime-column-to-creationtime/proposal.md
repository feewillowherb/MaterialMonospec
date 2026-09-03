## Why

UrbanManagement 实体已用 ABP `CreationTime`，但四张遗留表仍把该属性映射到列名 `AddTime`，输出 DTO 也沿用 `AddTime`。双名增加查询、migration 与运维 SQL 的摩擦。线上库已能完整 migrate；现在把物理列与 DTO 收成与代码一致的 `CreationTime`。

## What Changes

- 手写 EF `RenameColumn`：`AddTime` → `CreationTime`（数据保留）。
  - `GovProjects`
  - `GovSyncData`
  - `UrbanWeighingRecords`
  - `AttachmentFiles`
- 删除 `UrbanManagementDbContext` 中 `HasColumnName("AddTime")`；称重索引改为默认/与列名一致（去掉 `IX_UrbanWeighingRecords_AddTime` 别名）。
- 输出 DTO 属性 `AddTime` → `CreationTime`（`GovProjectDto`、`GovSyncDataDto`、`UrbanWeighingRecordOutputDto`）；`From*` 直接赋 `entity.CreationTime`。JSON 键随 ABP 惯例变为 `creationTime`。
- `UrbanPassageRecords` 及附件关联表建表时已是 `CreationTime`：**无**再改。
- **不做**：MaterialClient（其 `AddTime` 为 unix int 审计字段，语义不同）；萧山/JWT/Hub 协议；Receive 入参（本就不含 AddTime）。

**BREAKING**（库列名 + 列表 API JSON）：外部 SQL/报表若写 `AddTime` 须改为 `CreationTime`；消费 `addTime` 的 HTTP 客户端须改读 `creationTime`。Blazor 列表不展示该字段，同仓 App 无额外 UI 列改名。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `entity-migration`: `GovProject`（及同类审计实体）持久化创建时间为 `CreationTime`，不再叙述实体属性 `AddTime`。
- `urban-weighing-record-reception`: 入库时间字段为 Entity.`CreationTime`（ABP 自动填充），不再要求设置 `AddTime`。
- `urban-weighing-api`: 称重表列与输出 DTO 为 `CreationTime`。
- `gov-project-baseplatform-pull-sync`: 更新已有项目时不得覆盖 `CreationTime`（原 `AddTime` 运营字段）。
- `urban-management-crud`: 同步数据列表按 `CreationTime` 降序。
- `attachment-file-storage`: `AttachmentFile` 时间字段为 `CreationTime`。

## Impact

- **Repos**: UrbanManagement only（Mode A：自 trunk 切同名分支 `rename-urban-addtime-column-to-creationtime`）。
- **Code**: DbContext、手写 migration、三份输出 DTO、`From*`、注释/示例 `sorting: 'AddTime desc'`。
- **DB**: 四表列 rename + 称重 `AddTime` 索引名收敛。
- **API**: 列表/详情 JSON `addTime` → `creationTime`。
- **MC**: 无改动。
