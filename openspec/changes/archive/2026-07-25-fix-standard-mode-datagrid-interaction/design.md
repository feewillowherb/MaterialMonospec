## Context

`StandardModeFormView` 使用 Avalonia DataGrid 展示 `MaterialItems` 明细行，包含材料名称、单位、换算率、运单数量等列。

当前实现存在两类问题：

1. **材料列**：`CellTemplate` 内嵌 `Button` + `Click` 事件。DataGrid 默认将首次点击用于行/单元格选中，第二次点击才传递给内部 `Button`。此外 Popup 使用 `IsLightDismissEnabled="True"`，但 ViewModel 的 `IsMaterialPopupOpen` 仅在选中材料时置 `false`，轻触关闭后状态不同步，导致再次打开失败。

2. **单位列**：使用 `CellEditingTemplate` + ComboBox，点击即进入 DataGrid 编辑态。未选材料时 `MaterialUnits` 为空，ComboBox 仍获得焦点，DataGrid 无法退出编辑态，后续点击被拦截。

同一表格的「运单数量」列已采用正确模式：`IsReadOnly="True"` + 编辑器直接放在 `CellTemplate`（inline 编辑），不触发 DataGrid 编辑态。

## Goals / Non-Goals

**Goals:**

- 材料名称列单击一次打开材料选择 Popup
- Popup 任意关闭方式（选中材料、轻触外部）均同步 ViewModel 状态
- 单位列 inline 编辑，未选材料时禁用，不阻塞 DataGrid 其他交互
- 与「运单数量」列保持一致的 DataGrid 交互模式

**Non-Goals:**

- 不重构 MaterialsSelectionPopup 内部 UX（搜索、分页、双击选中等）
- 不改动 MaterialItemRow 换算/重量计算逻辑
- 不扩展 SolidWaste / Recycle 模式表单
- 不引入新的 ViewModel 命令或 Service

## Decisions

### D1：材料列采用 inline 点击 + `IsReadOnly="True"`

**选择**：移除 `CellTemplate` 内的 `Button`，改用可点击的 `Border`/`TextBlock` 绑定 `Tapped` 或 `PointerPressed`；列设置 `IsReadOnly="True"`。

**理由**：与运单数量列一致，避免 DataGrid 选中与 Button Click 的双击竞争。

**备选（未采用）**：
- 保留 Button，在 DataGrid `LoadingRow` 中预选中行 — 脆弱且依赖内部 API
- 使用 `CellEditEnding` 拦截 — 不解决根因

### D2：Popup 关闭双向同步

**选择**：在 `StandardModeFormView.axaml.cs` 订阅 `MaterialSelectionPopup.Closed`（或 `IsOpen` 属性变化），当 Popup 关闭且非材料选中流程时，将 `StandardWeighingDetailViewModel.IsMaterialPopupOpen` 设为 `false`；同时清空 `CurrentMaterialRow`（若尚未选中材料）。

**理由**：最小改动，不引入新命令；与现有 `WhenAnyValue(IsMaterialPopupOpen)` 单向绑定互补。

**实现要点**：
- 在 `SelectMaterialAsync` 正常关闭时避免重复处理（Closed 与 VM 置 false 顺序无害）
- Closed 回调中调用 `vm.CloseMaterialPopup()` 或直接设属性，避免在 code-behind 重复打开逻辑

### D3：单位列改为 inline ComboBox

**选择**：删除 `CellEditingTemplate`；在 `CellTemplate` 放置 ComboBox；列设 `IsReadOnly="True"`；ComboBox 设 `IsEnabled="{Binding SelectedMaterial, Converter={x:Static ObjectConverters.IsNotNull}}"`。

**理由**：彻底避免 DataGrid 编辑态；空 `MaterialUnits` 时 ComboBox 禁用，用户无法误入无效编辑。

**备选（未采用）**：
- `BeginningEdit` 取消编辑 — 仍有一次无效点击体验
- 保留 CellEditingTemplate 但在 `CellEditEnding` 强制 Commit — Avalonia DataGrid 行为不稳定

### D4：ViewModel 暴露 Popup 关闭方法

**选择**：在 `StandardWeighingDetailViewModel` 新增 package-private 或 public 方法 `CloseMaterialPopup()`，置 `IsMaterialPopupOpen = false` 并清空 `CurrentMaterialRow`（不触发材料选择）。

**理由**：保持 MVVM，code-behind 仅转发 Popup 关闭事件，不直接操作 row 状态。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| `Tapped` 与 DataGrid 滚动/选中仍有轻微冲突 | 列 `IsReadOnly="True"` + 事件 `Handled = true` |
| Popup Closed 与 SelectMaterial 竞态 | Closed 处理幂等；SelectMaterial 已置 false |
| inline ComboBox 在窄列内下拉被裁剪 | 沿用现有列宽 62px；ComboBox 下拉默认 Popup 层级，与现行为一致 |
| `ObjectConverters.IsNotNull` 对 Material 引用判空 | Avalonia 内置转换器，SelectedMaterial 为 null 时禁用 |

## Migration Plan

- 纯 UI 层改动，无数据库/API 迁移
- 部署后人工验证：材料单击打开、Popup 轻触关闭后再开、无材料时点单位不卡死、有材料时选单位正常

## Open Questions

_（无 — 实现路径明确，无需额外决策）_
