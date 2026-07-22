## 1. ViewModel — Popup 状态同步

- [ ] 1.1 在 `StandardWeighingDetailViewModel` 新增 `CloseMaterialPopup()` 方法：置 `IsMaterialPopupOpen = false` 并清空 `CurrentMaterialRow`（不触发材料选择）
- [ ] 1.2 确认 `SelectMaterialAsync` 关闭 Popup 逻辑与 `CloseMaterialPopup()` 不冲突（幂等）

## 2. StandardModeFormView — 材料列单击打开

- [ ] 2.1 材料名称列设置 `IsReadOnly="True"`
- [ ] 2.2 移除 `CellTemplate` 内 `Button`，改用 `Border`/`TextBlock` + `Tapped`（或 `PointerPressed`）触发打开材料 Popup
- [ ] 2.3 在 `StandardModeFormView.axaml.cs` 更新点击处理：设置 `PlacementTarget`、偏移量，调用 `OpenMaterialSelectionCommand`
- [ ] 2.4 订阅 `MaterialSelectionPopup.Closed`（或 `IsOpen` 变化），Popup 关闭时调用 `CloseMaterialPopup()`

## 3. StandardModeFormView — 单位列 inline 编辑

- [ ] 3.1 单位列设置 `IsReadOnly="True"`
- [ ] 3.2 删除 `CellEditingTemplate`，将 ComboBox 移入 `CellTemplate`（与运单数量列模式一致）
- [ ] 3.3 ComboBox 添加 `IsEnabled="{Binding SelectedMaterial, Converter={x:Static ObjectConverters.IsNotNull}}"`

## 4. 验证

- [ ] 4.1 手动验证：单击材料名称一次即可打开 Popup
- [ ] 4.2 手动验证：Popup 轻触关闭后，再次单击材料名称可正常打开
- [ ] 4.3 手动验证：未选材料时点击单位列，仍可点击材料列、运单数量及其他行
- [ ] 4.4 手动验证：选择材料后，单位 ComboBox 可用且切换单位正常更新换算率
- [ ] 4.5 运行 `openspec validate fix-standard-mode-datagrid-interaction --strict`
