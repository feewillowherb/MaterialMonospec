## Why

材料与供应商软删除后，订单列表 / 导出 / 按名称筛选仍走 Repository 默认过滤（或等价 `IsDeleted=0`），导致历史运单货名、供应商名缺失，且按已删主数据名称筛单会漏单。业务要求：**软删主数据不可再选择新建，但必须仍可被查询与展示。**

## What Changes

- 明确主数据（`Material` / `Provider`，及展示所需的 `MaterialUnit`）软删语义：**选型排除；按 Id 解析名称与历史筛选包含。**
- 修正运单查询 / 列表 DTO / 固废与标准导出中的材料·供应商字典与名称过滤，使软删行仍能解析出名称。
- 选型 / 分页选材·选供应商路径继续排除软删；新建或改单若提交已软删 Id SHALL 拒绝。
- 区分「软删除（行在、`IsDeleted=1`）」与「硬缺失（行不存在）」：仅硬缺失时名称输出空字符串。
- 不改库表结构；不恢复已软删主数据；不同步改 `material-provider-sync` 推送范围（仍只推未删除）。

## Capabilities

### New Capabilities

- `soft-deleted-master-query-display`：材料 / 供应商（及展示用单位）软删后的选型 vs 查询展示契约

### Modified Capabilities

- `solidwaste-excel-export`：货名 / 发货单位解析与货名·供应商名过滤须包含软删主数据；仅硬缺失时为空
- `standard-waybill-paged-query`：标准模式运单分页展示与按 MaterialName 筛选须包含软删主数据名称

## Impact

- **仓**：`repos/MaterialClient`（Common 服务层为主：`SolidWasteService`、`StandardService` / `StandardModeService`、列表 DTO 字典填充路径、材料/供应商选型 Service；可选新建守卫）
- **验证**：可用既有 Graph `waybill-softdelete-join-probe` / `solidwaste-oct-export-include-softdelete` 对照行为；应用内导出与列表抽检
- **非目标**：UrbanManagement / BasePlatform / Material WebApi；物理恢复软删行；改同步推送策略
