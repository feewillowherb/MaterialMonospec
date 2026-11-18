## Context

`Material` / `Provider` 实现 `IDeletionAuditedObject`。ABP Repository `GetQueryableAsync()` 默认排除软删行。运单查询与导出通过 `BuildMaterialDictAsync` / `BuildProviderDictAsync`（及固废同名方法）按 Id 填名称；按货名 / 供应商名筛选也先查主表再匹配 Waybill。结果：软删后历史单名称空、按已删名筛选漏单。选型侧（如 `ProviderService` 显式 `!IsDeleted`）行为正确，应保留。

现场库（固废 `1112`）验证：材料多为软删而非硬缺失；10 月导出在含软删解析后可还原货名。

约束：仅 MaterialClient；无 DB schema 变更；不用 tuple 作新 API；纯逻辑不新注册 DI。

## Goals / Non-Goals

**Goals:**

- 选型 / 新建：软删材料、供应商不可选、不可提交
- 查询 / 展示 / 导出 / 按名称筛历史单：按 Id 解析名称时包含软删；`MaterialUnit` 展示同理
- 硬缺失（无行）仍输出空字符串且不抛错
- 修正与本语义冲突的 `solidwaste-excel-export` / `standard-waybill-paged-query` 要求

**Non-Goals:**

- 恢复或 bulk 取消软删
- 改 `MaterialProviderSyncService` 推送范围（仍只处理未删除）
- UrbanManagement / 服务端平台 API
- 以订单冗余字段（`WaybillMaterial.MaterialName`）全面替代主表解析（可作为后续增强，本 change 不依赖）

## Decisions

### 1. 双路径查询语义（选型 vs 展示）

- **选型**：继续默认软删过滤或显式 `!IsDeleted`（材料分页/列表与供应商一致）。
- **展示与历史筛选**：对按 Id 批量取名、以及「用名称反查 Id 再筛 Waybill」的路径，使用 `IgnoreQueryFilters()`（或等效：绕过软删过滤器后再按 Id / 名称条件查询），**不再**叠加 `!IsDeleted`。

**Alternatives considered:** 全局关闭软删过滤器（拒绝：选型会漏出已删项）；仅改导出 Graph（拒绝：不修产品）。

### 2. 共享解析方式，不新增 Mapper / DI Service

在 Common 内用 **私有方法或 static 辅助**（如按 Id 列表加载 `Material`/`Provider`/`MaterialUnit`，含软删）供 `SolidWasteService`、`StandardService`、`StandardModeService` 及列表字典填充复用。满足 `minimal-di`：无 I/O 生命周期的纯组合不注册 Transient。

**Alternatives considered:** 新建 `IMasterLookupService` 并注册 DI（拒绝：可 static/私有完成）；到处复制 `IgnoreQueryFilters`（可接受但易漏，优先抽一层）。

### 3. 新建守卫

称重/运单写入路径若携带已软删的 `MaterialId` / `ProviderId`，SHALL 拒绝（明确错误），防止绕过 UI。守卫可与现有校验同层，不扩大无关重构。

### 4. Spec 冲突处理

`solidwaste-excel-export` 中「已删除或不存在 → 空字符串」改为：**软删仍输出名称；仅行不存在为空**。`standard-waybill-paged-query` 关联名称与 MaterialName 筛选对齐同一语义。

### 5. 验证

Apply 后可用 `pipelines/graphs/materialclient/waybill-softdelete-join-probe` 与应用内列表/导出抽检；不必把 Graph 改成产品替代实现。

## Risks / Trade-offs

- [漏改某条查询路径] → Mitigation：tasks 按服务清单枚举；以「按 Id 填名 / 按名筛 Waybill」为搜索关键词扫一遍 Common
- [选型路径误加 IgnoreQueryFilters] → Mitigation：选型方法保持 `!IsDeleted`；code review 对照双路径
- [IgnoreQueryFilters 拉出其它全局过滤器] → Mitigation：仅用于 Material/Provider/MaterialUnit 短查询；条件仍限 Id 集合或名称 Contains
- [与「关联不存在则空」旧文案混淆] → Mitigation：delta spec 明确 soft vs hard

## Migration Plan

- 纯代码行为变更，无 migration
- 发布后：软删主数据的历史单名称应立即可见；无需数据修复
- 回滚：还原展示路径过滤即可

## Open Questions

- （无阻塞）列表 UI 是否对软删材料加「已删除」标记：本 change 不要求，仅保证名称可查
