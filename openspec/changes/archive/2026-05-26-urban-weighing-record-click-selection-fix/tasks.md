## 1. ViewModel — 添加 [ReactiveCommand] 属性

- [x] 1.1 在 `UrbanAttendedWeighingViewModel.cs` 的 `SelectListItem` 方法上添加 `[ReactiveCommand]` 属性，将访问级别从 `public` 改为 `private`，使 ReactiveUI Source Generator 生成 `SelectListItemCommand`

## 2. AXAML — 行模板从 Border 重构为 Button

- [x] 2.1 在 `UrbanAttendedWeighingWindow.axaml` 的 ItemsControl.ItemTemplate 中，将行容器从 `<Border>` 改为 `<Button Classes="transparent-button">`，设置 `BorderThickness="0,0,0,1"` `BorderBrush="#F1F5F9"` `Padding="12,6"` `HorizontalAlignment="Stretch"` `HorizontalContentAlignment="Stretch"`
- [x] 2.2 添加 Command 绑定：`Command="{Binding $parent[ItemsControl].((vm:UrbanAttendedWeighingViewModel)DataContext).SelectListItemCommand}"` 和 `CommandParameter="{Binding}"`
- [x] 2.3 添加选中高亮 Background MultiBinding：使用 `EqualityToColorConverter` 绑定当前项 `Path="."` 和 `$parent[ItemsControl].((vm:UrbanAttendedWeighingViewModel)DataContext).SelectedListItem`
- [x] 2.4 移除 Border 的 `PointerPressed="OnRecordClick"` 和 `Tag="{Binding}"`
- [x] 2.5 移除 Border.Styles 中的 pointer-over hover 样式（选中高亮由 EqualityToColorConverter 接管）

## 3. AXAML — 审批列从 Button 降级为 TextBlock

- [x] 3.1 将第4列的 `<Button Classes="primary-button" Content="审批" ... />` 替换为 `<TextBlock Text="审批" FontSize="12" Foreground="#3B82F6" FontWeight="Medium" VerticalAlignment="Center" HorizontalAlignment="Center" />`

## 4. Code-behind — 删除 OnRecordClick

- [x] 4.1 在 `UrbanAttendedWeighingWindow.axaml.cs` 中删除 `OnRecordClick` 方法

## 5. 验证

- [x] 5.1 编译确认无错误，验证 ReactiveUI Source Generator 正确生成 `SelectListItemCommand`
- [x] 5.2 运行应用，点击车辆记录行确认：选中高亮生效、照片侧栏加载、审批列文本显示正常
