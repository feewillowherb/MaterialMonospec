## 1. Service Layer

- [x] 1.1 Add `UpdateWeighingRecordAsync(long weighingRecordId, string plateNumber, decimal totalWeight)` method to `IWeighingRecordService` interface in `MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs`
- [x] 1.2 Implement `UpdateWeighingRecordAsync` in `WeighingRecordService`: fetch record by ID, update PlateNumber and TotalWeight on the entity, persist via repository, locate UrbanWeighingExtension via `IUrbanWeighingExtensionService.GetByWeighingRecordIdAsync`, and reset SyncStatus to Pending via `UpdateSyncStatusAsync`. Wrap in `[UnitOfWork]`.

## 2. Edit Dialog

- [x] 2.1 Create `WeighingRecordEditDialogViewModel.cs` in `MaterialClient.Urban/ViewModels/` with `[Reactive] PlateNumber` (string), `[Reactive] TotalWeight` (string for TextBox binding), an `EditResult` property, `[ReactiveCommand] Save()` that parses TotalWeight to decimal and sets Result, and `[ReactiveCommand] Cancel()` that sets Result to null
- [x] 2.2 Create `WeighingRecordEditDialog.axaml` in `MaterialClient.Urban/Views/Dialogs/` following the AddCameraDialog pattern: Window with centered owner, Grid layout with PlateNumber TextBox, TotalWeight TextBox, Cancel/Save buttons
- [x] 2.3 Create `WeighingRecordEditDialog.axaml.cs` code-behind: constructor accepting ViewModel, subscribe to SaveCommand and CancelCommand to call `Close(viewModel.Result)` / `Close(null)`

## 3. ViewModel Approval Flow

- [x] 3.1 Add `GetWindow()` helper method to `UrbanAttendedWeighingViewModel` using `IClassicDesktopStyleApplicationLifetime.Windows.FirstOrDefault(w => w.DataContext == this)` pattern
- [x] 3.2 Add `[ReactiveCommand] ApproveRecordAsync(UrbanWeighingListItemDto?)` method: create dialog ViewModel with item's current values, show dialog via `ShowDialog<EditResult>`, call `UpdateWeighingRecordAsync` on non-null result, then call `ReloadRecordsAsync`

## 4. ListBox Migration

- [x] 4.1 Replace `ItemsControl` with `ListBox` in `UrbanAttendedWeighingWindow.axaml` at Grid.Row=3: set `ItemsSource="{Binding ListItems}"`, `SelectedItem="{Binding SelectedListItem, Mode=TwoWay}"`, keep `DataTemplate` with `x:DataType="dtos:UrbanWeighingListItemDto"`
- [x] 4.2 Add inline `<ListBox.Styles>` to remove default chrome: transparent `ListBox` background, zero border, `ListBoxItem` with transparent background and `HorizontalContentAlignment="Stretch"`, selected background `#E3F2FD`, hover background `#F0F7FF`, row separator `BorderThickness="0,0,0,1"` with `BorderBrush="#F1F5F9"`
- [x] 4.3 Update row `DataTemplate`: remove the wrapping `Button` element, use a plain `Grid` with the existing 5-column layout as the direct content of `ListBoxItem`
- [x] 4.4 Restore "审批" as a `<Button Classes="primary-button">` in column 5 with `Command="{Binding #UrbanAttendedWeighingWindowRoot.DataContext.ApproveRecordCommand}"` and `CommandParameter="{Binding}"`
- [x] 4.5 Remove the `SelectListItemCommand` binding from the old Button wrapper (now deleted) and verify no references to `SelectListItemCommand` remain in the AXAML

## 5. Cleanup

- [x] 5.1 Remove `[ReactiveCommand] SelectListItem(UrbanWeighingListItemDto item)` method from `UrbanAttendedWeighingViewModel.cs` — the `[Reactive] SelectedListItem` property and its `WhenAnyValue` subscription for photo loading remain unchanged
- [x] 5.2 Remove the `EqualityToColorConverter` import and `MultiBinding` from the row template (selection highlighting is now handled by `ListBoxItem:selected` style)
- [x] 5.3 Verify the `WhenAnyValue(x => x.SelectedListItem)` subscription that triggers `UpdatePhotoPathsAsync` still fires correctly when `ListBox.SelectedItem` changes — the `SelectedItem` two-way binding writes to `SelectedListItem` which triggers the existing reactive subscription, so photo sidebar updates should work without modification
