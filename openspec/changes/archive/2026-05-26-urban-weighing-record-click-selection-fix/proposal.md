## Why

UrbanAttendedWeighingWindow 中的车辆记录行选择使用 `Border` + `PointerPressed` 事件实现，存在两个缺陷：**事件拦截**导致点击不可靠（第4列"审批" Button 吞掉事件），**无选中视觉反馈**导致用户无法感知操作是否生效。同项目中的 WeighingRecordListView 已使用 `Button` + Command 绑定 + `EqualityToColorConverter` 高亮的成熟模式，应统一采用。

## What Changes

- 将 `SelectListItem` 方法添加 `[ReactiveCommand]` 属性，生成 `SelectListItemCommand`
- 行模板容器从 `Border` 改为 `Button`（transparent-button 样式），通过 `$parent[ItemsControl]` 绑定 Command
- 添加 `EqualityToColorConverter` + `MultiBinding` 实现选中行背景高亮
- "审批"列从 `Button` 降级为 `TextBlock`（避免 Button 嵌套导致事件冲突）
- 删除 code-behind 中的 `OnRecordClick` 方法及 `PointerPressed` 事件绑定

## Capabilities

### New Capabilities

无新增能力。

### Modified Capabilities

无既有 spec 需要修改。此变更属于纯 UI 交互修复，不引入新的行为规格需求。

## Impact

**涉及文件（3个）**：

| 文件 | 变更类型 | 说明 |
|---|---|---|
| `UrbanAttendedWeighingViewModel.cs` | 修改 | `SelectListItem` 添加 `[ReactiveCommand]` 属性 |
| `UrbanAttendedWeighingWindow.axaml` | 修改 | 行模板 Border→Button，添加选中高亮绑定，审批列 Button→TextBlock |
| `UrbanAttendedWeighingWindow.axaml.cs` | 修改 | 删除 `OnRecordClick` 方法 |

**参考实现**（只读，不修改）：

| 文件 | 参考目的 |
|---|---|
| `WeighingRecordListView.axaml` | 行选择 Button + Command + 高亮绑定模式 |
| `AttendedWeighingViewModel.cs` | `[ReactiveCommand]` + `SelectListItemCommand` 模式 |
| `EqualityToColorConverter` | 选中行背景色转换器 |

**照片加载链路**已正确存在（`WhenAnyValue(x => x.SelectedListItem)` → `UpdatePhotoPathsAsync` → 更新 `LprPhotoPath`/`CameraPhotoPath`），无需修改。

**不受影响**：无 API 变更、无依赖变更、无向后兼容问题。
