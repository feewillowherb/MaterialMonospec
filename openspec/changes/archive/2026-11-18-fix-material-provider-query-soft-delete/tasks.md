## 1. 分支与盘点

- [x] 1.1 在 MaterialClient 自 trunk 切出同名分支 `fix-material-provider-query-soft-delete`（Mode A）
- [x] 1.2 盘点 Common 中「按 Id 填 Material/Provider/MaterialUnit 名」与「按名称反查 Id 再筛 Waybill」调用点（至少含 `SolidWasteService`、`StandardService`、`StandardModeService`、列表 DTO 字典填充）

## 2. 展示 / 查询含软删

- [x] 2.1 抽取按 Id 批量加载主数据的辅助（含软删 / `IgnoreQueryFilters` 等价），不新增 DI Mapper Service
- [x] 2.2 修正 `SolidWasteBuildMaterialDictAsync` / `SolidWasteBuildProviderDictAsync` 及货名、供应商名过滤，含软删
- [x] 2.3 修正 `StandardService` / `StandardModeService` 的 `BuildMaterialDictAsync` / `BuildProviderDictAsync` 与 MaterialName 过滤，含软删
- [x] 2.4 修正称重/运单列表 `materialsDict` / `materialUnitsDict` / 供应商名填充路径，使软删主数据名称可见
- [x] 2.5 确认硬缺失（无行）仍输出空字符串且不抛错

## 3. 选型排除与写入守卫

- [x] 3.1 确认材料选型/分页列表与供应商选型一致排除 `IsDeleted`
- [x] 3.2 在新建/改单写入路径拒绝已软删的 `MaterialId` / `ProviderId`

## 4. 验证

- [x] 4.1 用现场或种子库抽检：软删材料运单列表/导出货名非空；选型列表无该项
- [x] 4.2 （可选）对照 `pipelines/graphs/materialclient/waybill-softdelete-join-probe` 缺口分类理解
- [x] 4.3 勾选本 tasks；准备 `/opsx:archive` 前的 agents 校验（若需要）
