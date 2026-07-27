## Why

Standard 模式（`StandardModeFormView`）材料明细 DataGrid 存在两处交互缺陷：点击「材料名称」常需多次点击才打开选择弹窗；在未选择材料时点击「单位」列会导致 DataGrid 进入编辑态后无法点击其他单元格。这些问题影响称重员录入效率，且与同一表格中「运单数量」列已采用的 inline 编辑模式不一致。

## What Changes

- 材料名称列：单击一次即可打开材料选择 Popup，无需先选中行再二次点击。
- 材料选择 Popup：轻触关闭（Light Dismiss）后同步重置 ViewModel 的 `IsMaterialPopupOpen`，避免再次点击无响应。
- 单位列：改为与「运单数量」一致的 inline 编辑模式（`IsReadOnly="True"` + `CellTemplate` 内嵌 ComboBox），避免进入 DataGrid 编辑态。
- 单位列：未选择材料时禁用单位 ComboBox，防止空数据源触发编辑态卡死。
- 不改动 SolidWaste / Recycle 模式表单（它们不使用此 DataGrid 布局）。

## Capabilities

### New Capabilities

_（无）_

### Modified Capabilities

- `detail-viewmodel-hierarchy`：新增 Standard 模式材料明细 DataGrid 的交互需求（材料单击打开 Popup、Popup 关闭状态同步、单位列 inline 编辑与前置依赖）。

## Impact

### Code Changes

| 文件路径 | 变更类型 | 变更原因 |
|-----------|-------------|--------|
| `repos/MaterialClient/src/MaterialClient.AttendedWeighing/Views/Controls/StandardModeFormView.axaml` | 修改 | 材料列/单位列 DataGrid 列定义与交互模式 |
| `repos/MaterialClient/src/MaterialClient.AttendedWeighing/Views/Controls/StandardModeFormView.axaml.cs` | 修改 | Popup 关闭状态同步、材料列点击处理 |
| `repos/MaterialClient/src/MaterialClient.AttendedWeighing/ViewModels/StandardWeighingDetailViewModel.cs` | 修改 | Popup 关闭时重置 `IsMaterialPopupOpen` |

### 不受影响的范围

- 无 API / 数据库变更
- SolidWasteModeFormView、RecycleModeFormView 不受影响
- MaterialItemRow 业务逻辑（换算、重量计算）不变
- MaterialsSelectionPopup 选择逻辑不变
