## 1. MaterialClient — Entity & Extension Layer

- [x] 1.1 `UrbanWeighingExtension.cs`: Remove `EditHistoryJson` property and `[NotMapped] EditHistory` computed property; add `IHasExtraProperties` to class declaration; add `_extraProperties` backing field and `ExtraProperties` property (following `WeighingRecord` / `Waybill` pattern)
- [x] 1.2 `EditEntry.cs`: Refactor from incremental model to snapshot model — remove `Field`, `OldValue`, `NewValue` properties; replace with `ChangedAt` (DateTime), `PlateNumber` (string), `TotalWeight` (decimal), `AnomalyReason` (string?)
- [x] 1.3 `EditHistoryExtensions.cs` (new file in `Common/Entities/Urban/`): Create static class with `GetEditHistory(this UrbanWeighingExtension ext)` returning `List<EditEntry>` (deserialize from `ExtraProperties["EditHistory"]`, empty list on missing/failed) and `SetEditHistory(this UrbanWeighingExtension ext, List<EditEntry>? entries)` (serialize to `ExtraProperties["EditHistory"]`, remove key on null/empty)

## 2. MaterialClient — EF Core & Migration

- [x] 2.1 `MaterialClientDbContext.cs`: In `UrbanWeighingExtension` configuration block, remove `entity.Property(e => e.EditHistoryJson)` line and `entity.Ignore(e => e.EditHistory)` line
- [x] 2.2 Generate EF Core migration: DropColumn `EditHistoryJson` from `UrbanWeighingExtensions` table; verify `ExtraProperties` column is auto-added by ABP convention for `IHasExtraProperties`

## 3. MaterialClient — Service Layer

- [x] 3.1 `IUrbanWeighingExtensionService.cs`: Update `AppendEditEntryAsync` signature — replace per-field `field`/`oldValue`/`newValue` params with complete snapshot params (PlateNumber, TotalWeight, AnomalyReason); update XML doc to reference `ExtraProperties`
- [x] 3.2 `UrbanWeighingExtensionService.cs` (implementation of `AppendEditEntryAsync`): Replace `extension.EditHistory` / `extension.EditHistoryJson` usage with `extension.GetEditHistory()` / `SetEditHistory()` extension methods; create new `EditEntry` snapshot (ChangedAt, PlateNumber, TotalWeight, AnomalyReason) and append to history list

## 4. MaterialClient — DTO & Upload

- [x] 4.1 `UrbanWeighingRecordSubmitDto.cs`: Remove `EditHistoryJson` property and its `[JsonPropertyName("editHistoryJson")]` attribute; add `Dictionary<string, object?>? ExtraProperties` property with `[JsonPropertyName("extraProperties")]`
- [x] 4.2 `UrbanServerUploadService.cs`: Replace `EditHistoryJson = extension?.EditHistoryJson` assignment with building `ExtraProperties` dictionary from `extension.GetEditHistory()` (serialize to JSON string, set as dictionary value for key `"EditHistory"`)

## 5. UrbanManagement — Entity Layer

- [x] 5.1 `UrbanWeighingRecord.cs`: Remove `EditHistoryJson` property and its XML doc comment; add `IHasExtraProperties` to class declaration; add `_extraProperties` backing field and `ExtraProperties` property (following ABP convention pattern from `WeighingRecord`)

## 6. UrbanManagement — EF Core & Migration

- [x] 6.1 `UrbanManagementDbContext.cs`: In `UrbanWeighingRecord` configuration block, remove `b.Property(e => e.EditHistoryJson)` line
- [x] 6.2 Generate EF Core migration: DropColumn `EditHistoryJson` from `UrbanWeighingRecords` table; verify `ExtraProperties` column is auto-added by ABP convention for `IHasExtraProperties`

## 7. UrbanManagement — DTO Layer

- [x] 7.1 `UrbanWeighingRecordDtos.cs`: In `UrbanWeighingRecordReceiveInputDto`, remove `EditHistoryJson` property; add `Dictionary<string, object?>? ExtraProperties` property
- [x] 7.2 `UrbanWeighingRecordOutputDto.cs`: Remove `EditHistoryJson` property; add `Dictionary<string, object?>? ExtraProperties` property; update `FromEntity` method to copy entity's `ExtraProperties` entries to the DTO's `ExtraProperties` dictionary

## 8. UrbanManagement — Service Layer

- [x] 8.1 `UrbanWeighingRecordAppService.cs` — `ReceiveAsync`: Replace `EditHistoryJson = input.EditHistoryJson` assignment with copying `input.ExtraProperties` (specifically the `"EditHistory"` key) to `record.ExtraProperties`
- [x] 8.2 `UrbanWeighingRecordAppService.cs` — `ApproveAsync`: Replace per-field edit entry logic (Field/OldValue/NewValue comparisons) with snapshot approach — after approval, create a single `EditEntry` containing the post-approval state (ChangedAt, PlateNumber, TotalWeight, AnomalyReason=""); read existing history from `record.GetProperty<string>("EditHistory")`, append the snapshot, and write back via `record.SetProperty("EditHistory", ...)`. Remove the internal `EditEntryDto` private class and per-field diff logic

## 9. UrbanManagement — UI Layer

- [x] 9.1 `WeighingApproval.razor`: In `OpenApprovalDialog` method, replace `record.EditHistoryJson` deserialization with reading from `record.ExtraProperties` dictionary; extract the `"EditHistory"` string value and deserialize to `List<EditHistoryEntry>`; update internal `EditHistoryEntry` class to match snapshot model (PlateNumber, TotalWeight, AnomalyReason, ChangedAt — remove Field/OldValue/NewValue); update timeline rendering to display each snapshot's full field values
