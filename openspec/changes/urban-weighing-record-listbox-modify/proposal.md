## Why

The current `UrbanAttendedWeighingWindow` wraps each list row in a `Button` for selection, but Avalonia does not support nested Buttons. This forces the "审批" (approval) action button on each row to either be a non-interactive `TextBlock` (per spec) or silently conflict with the parent `Button`. Either way, users cannot trigger approval. The business requires that approval allow editing weight and plate number, then reset the sync status to `Pending` for re-upload.

## What Changes

- **Replace `ItemsControl` + `Button` rows with `ListBox`**: Use Avalonia `ListBox` with `SelectedItem` two-way binding for row selection. `ListBoxItem` is not a `Button`, so child elements (including action buttons) remain fully interactive.
- **Restore "审批" as an interactive `Button`**: Each row's action column renders a real `Button` bound to `ApproveRecordCommand`, passing the current `UrbanWeighingListItemDto` as `CommandParameter`.
- **Add `WeighingRecordEditDialog`**: A modal dialog (AXAML + code-behind + ViewModel) following the `AddCameraDialog` pattern, with editable fields for `PlateNumber` (TextBox) and `TotalWeight` (TextBox, decimal), plus Save/Cancel actions.
- **Add `UpdateWeighingRecordAsync` to `IWeighingRecordService`**: Service method that updates `PlateNumber` and `TotalWeight` on a `WeighingRecord`, resets the associated `UrbanWeighingExtension.SyncStatus` to `Pending`, and triggers list refresh.
- **Add `ApproveRecordCommand` to `UrbanAttendedWeighingViewModel`**: Opens the edit dialog, processes the result, calls the update service, and refreshes the list.
- **Remove `SelectListItemCommand`**: No longer needed since `ListBox.SelectedItem` handles selection natively.
- **Photo sidebar update preserved**: `SelectedListItem` remains a `[Reactive]` property with an existing `WhenAnyValue` subscription that calls `UpdatePhotoPathsAsync`. Since `ListBox.SelectedItem` binds two-way to `SelectedListItem`, row selection still triggers photo loading automatically — no additional wiring needed.

## Capabilities

### New Capabilities
- `weighing-record-approval`: Covers the approval workflow — edit dialog UI (PlateNumber + TotalWeight fields, Save/Cancel), `ApproveRecordCommand` on the ViewModel, and the `UpdateWeighingRecordAsync` service method that persists edits and resets `UrbanWeighingExtension.SyncStatus` to `Pending`.

### Modified Capabilities
- `urban-weighing-record-selection`: Row selection mechanism changes from `ItemsControl` + per-row `Button` with `SelectListItemCommand` to `ListBox` with `SelectedItem` two-way binding. The `[ReactiveCommand] SelectListItem` method and its generated `SelectListItemCommand` are removed. Visual highlighting moves from `EqualityToColorConverter` on `Button.Background` to `ListBoxItem` container style. The existing `WhenAnyValue(x => x.SelectedListItem)` subscription that triggers `UpdatePhotoPathsAsync` for the photo sidebar is preserved — `ListBox.SelectedItem` two-way binding writes through to `SelectedListItem`, so photo updates continue to fire on selection change.
- `urban-weighing-list-presentation`: List container changes from `ItemsControl` to `ListBox`. The `ItemsSource` binding to `ListItems` is preserved, but the container type and item template structure change to accommodate `ListBox` semantics and restore the "审批" action as an interactive `Button`.

## Impact

**Files modified (3):**

| File | Change |
|---|---|
| `src/MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` | `ItemsControl` → `ListBox` with custom `ItemContainerStyle`; restore "审批" `Button` with `Command` binding; remove `EqualityToColorConverter`-based background logic; add custom `ListBox` style to remove default chrome |
| `src/MaterialClient.Urban/ViewModels/UrbanAttendedWeighingViewModel.cs` | Remove `[ReactiveCommand] SelectListItem`; add `SelectedListItem` setter handling (if needed for photo loading); add `[ReactiveCommand] ApproveRecordAsync` that opens dialog and calls service |
| `src/MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs` | Add `UpdateWeighingRecordAsync(long weighingRecordId, string plateNumber, decimal totalWeight)` method; update `IWeighingRecordService` interface |

**Files added (3):**

| File | Purpose |
|---|---|
| `src/MaterialClient.Urban/Views/Dialogs/WeighingRecordEditDialog.axaml` | Edit dialog UI with PlateNumber and TotalWeight TextBoxes |
| `src/MaterialClient.Urban/Views/Dialogs/WeighingRecordEditDialog.axaml.cs` | Code-behind: subscribes to Save/Cancel commands, calls `Close(result)` |
| `src/MaterialClient.Urban/ViewModels/WeighingRecordEditDialogViewModel.cs` | ViewModel with `[Reactive]` properties for `PlateNumber` and `TotalWeight`, `Result` property, Save/Cancel commands |

**Unaffected**: Photo loading, anomaly detection, pagination, device status monitoring, tab filtering, background sync worker, `WeighingWindowBase` control.
