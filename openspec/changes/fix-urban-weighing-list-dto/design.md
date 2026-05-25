## Context

`UrbanAttendedWeighingViewModel` 将 `ObservableCollection<WeighingRecord>` 暴露给 `ItemsControl`，XAML 使用 `x:DataType="entities:WeighingRecord"` 并绑定 `UrbanExtension.SyncStatus`。`IUrbanWeighingExtensionService.GetPagedWithRecordsAsync` 接受 6 个孤立参数，返回 `PagedResultDto<WeighingRecord>`，且在查询结果上执行 `Record.UrbanExtension = Extension`——与 `refactor-urban-weighing-extension-decouple` 后「无导航属性」的实体模型不一致。

列表曾出现「`ReloadRecordsAsync` 后 UI 不刷新」问题，部分源于一次性 `ItemsSource` 赋值；已改为 XAML `{Binding ListItems}` + 就地 `Clear`/`Add`，本变更在 DTO 层固化契约。

## Goals / Non-Goals

**Goals:**

- UI 层（ViewModel + XAML）仅绑定 DTO，不引用 `MaterialClient.Common.Entities` 中的称重实体
- 分页查询使用单一 input DTO；服务返回 `PagedResultDto<UrbanWeighingListItemDto>`
- ViewModel 集合命名为 `ListItems`，`ReloadRecordsAsync` 正确填充并触发列表渲染
- 选中行、侧栏照片加载使用 DTO 中的 `WeighingRecordId`（及必要展示字段）

**Non-Goals:**

- 不改变称重创建、后台 Pending 上传等仍使用实体的内部路径（除非直接依赖旧分页 API 的调用方）
- 不重构 MaterialClient 主程序 AttendedWeighing 列表
- 不新增审批、筛选控件的业务逻辑（仅绑定 DTO 字段）

## Decisions

### 1. DTO 放置位置

**决定**：在 `MaterialClient.Common/Dtos/Urban/`（或 `Models/Urban/`）定义 `UrbanWeighingListItemDto` 与 `GetUrbanWeighingListInput`。

**理由**：由 Domain Service 组装，ViewModel 与测试共用；Urban 项目引用 Common 即可，避免 UI 项目重复定义。

**备选**：DTO 仅放在 `MaterialClient.Urban` —— 拒绝，服务层不应依赖 Urban UI 程序集。

### 2. 列表项 DTO 字段（扁平化）

**决定**：`UrbanWeighingListItemDto` 包含 UI 所需标量：

| 字段 | 用途 |
|------|------|
| `WeighingRecordId` | 选中、附件查询 |
| `PlateNumber` | 列表列 |
| `AddDate` | 列表列 |
| `TotalWeight` | 列表列 |
| `SyncStatus?` | 状态徽章（null 表示无扩展行） |

**理由**：避免 XAML 绑定嵌套导航；与解耦后的实体模型一致。

### 3. 服务 API 形状

**决定**：

```csharp
Task<PagedResultDto<UrbanWeighingListItemDto>> GetPagedListItemsAsync(GetUrbanWeighingListInput input);
```

`GetUrbanWeighingListInput` 包含：`PageIndex`, `PageSize`, `TabFilter`, `SearchText`, `StartTime`, `EndTime`。

**理由**：满足「入参 DTO 打包」；方法名表达返回列表项而非实体。旧 `GetPagedWithRecordsAsync` 删除或保留为 obsolete 一层转发（实现阶段优先直接替换调用方）。

**备选**：保留多参数重载 —— 拒绝，与要求冲突。

### 4. ViewModel 集合与重载

**决定**：

- `[Reactive] ObservableCollection<UrbanWeighingListItemDto> ListItems`
- `SelectedListItem` 替代 `SelectedRecord`（或保留语义化命名 `SelectedListItem`）
- `ReloadRecordsAsync`：构建 `GetUrbanWeighingListInput` 从当前筛选状态，主线程 `ListItems.Clear()` + `Add` DTO

**理由**：命名与用户要求一致；就地更新集合实例，绑定稳定。

### 5. XAML 与 code-behind

**决定**：

- `ItemsSource="{Binding ListItems}"`
- `DataTemplate x:DataType` 指向 DTO 类型（`clr-namespace` 或 `using:`）
- `OnRecordClick`：`Tag` 绑定 DTO，`SelectListItem(dto)` 传入 `WeighingRecordId` 加载照片

### 6. 映射实现

**决定**：在 `UrbanWeighingExtensionService` 的 join 查询投影为 `UrbanWeighingListItemDto`，不再赋值 `Record.UrbanExtension`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 破坏依赖 `GetPagedWithRecordsAsync` 的测试/调用方 | 全局搜索替换；更新 `UrbanWeighingExtensionQueryTests` |
| `SyncStatus?` 为 null 时徽章显示 | XAML 转换器或 DTO 上 `IsSyncFailed` 计算属性 |
| 编译期绑定路径变更 | 更新 `x:DataType` 与 xmlns |

## Migration Plan

1. 新增 DTO 与 input 类型
2. 实现/替换服务方法并删除导航赋值
3. 更新 ViewModel + XAML + code-behind
4. 运行 `MaterialClient.Common.Tests` 与 Urban 应用手动验证列表/分页/Tab 筛选

无数据库迁移。

## Open Questions

- 无（审批按钮、日期筛选 TextBox 绑定可留待后续 change，本变更仅保证列表 DTO 与 `ListItems` 渲染）
