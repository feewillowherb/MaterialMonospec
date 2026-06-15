## 1. MaterialClient — Data Model

- [x] 1.1 Create `EditEntry` POCO class in `MaterialClient.Common/Entities/Urban/EditEntry.cs` with `Field`, `OldValue`, `NewValue`, `ChangedAt` properties
- [x] 1.2 Add `AnomalyReason` (string?) and `EditHistoryJson` (string?) properties to `UrbanWeighingExtension` entity
- [x] 1.3 Add `[NotMapped]` computed property `EditHistory` (List\<EditEntry\>) with JSON serialize/deserialize logic following the `Materials`/`MaterialsJson` pattern
- [x] 1.4 Update `MaterialClientDbContext.OnModelCreating` to configure `AnomalyReason` (max-length 32) and `EditHistoryJson` (nullable text) columns
- [x] 1.5 Create EF Core migration adding `AnomalyReason` and `EditHistoryJson` columns to `UrbanWeighingExtensions` table

## 2. MaterialClient — Service Layer

- [x] 2.1 Modify `UrbanWeighingExtensionService.CreateForRecordAsync` to call `GetAnomalyReason` and persist the result to `AnomalyReason` on the extension
- [x] 2.2 Add `AppendEditEntryAsync(Guid extensionId, string field, string oldValue, string newValue)` method to `IUrbanWeighingExtensionService` interface
- [x] 2.3 Implement `AppendEditEntryAsync` in `UrbanWeighingExtensionService`: read current `EditHistoryJson`, deserialize, append entry with `changedAt = DateTime.UtcNow`, serialize, persist
- [x] 2.4 Modify `GetPagedListItemsAsync` to read `AnomalyReason` from `x.Extension.AnomalyReason` instead of calling `_anomalyDetector.GetAnomalyReason` at query time

## 3. MaterialClient — Approval Flow Integration

- [x] 2.5 Capture old `PlateNumber` and `TotalWeight` values before calling `UpdateWeighingRecordAsync` in the approval ViewModel flow
- [x] 2.6 After successful `UpdateWeighingRecordAsync`, call `AppendEditEntryAsync` for each changed field (PlateNumber, TotalWeight) on the associated `UrbanWeighingExtension`
- [x] 2.7 Update the anomaly recalculation flow to also persist the new `AnomalyReason` value to `UrbanWeighingExtension.AnomalyReason`

## 4. MaterialClient — Upload Payload

- [x] 4.1 Update the upload DTO/payload construction in `UrbanWeighingUploadService` to include `AnomalyReason` and `EditHistoryJson` from the extension entity

## 5. UrbanManagement — Data Model

- [x] 5.1 Add `AnomalyReason` (string?) and `EditHistoryJson` (string?) properties to `UrbanWeighingRecord` entity
- [x] 5.2 Add `AnomalyReason` and `EditHistoryJson` to `UrbanWeighingRecordOutputDto` and update `FromEntity` mapping
- [x] 5.3 Add `AnomalyReason` and `EditHistoryJson` to `UrbanWeighingRecordReceiveInputDto`
- [x] 5.4 Update `UrbanManagementDbContext` Fluent API configuration for the new fields

## 6. UrbanManagement — Service Layer

- [x] 6.1 Modify `ReceiveAsync` to persist `AnomalyReason` and `EditHistoryJson` from input DTO to the `UrbanWeighingRecord` entity
- [x] 6.2 Modify `ApproveAsync` to: capture old values, build edit entries, append to `EditHistoryJson` array, update `PlateNumber`/`TotalWeight`, re-evaluate `IsAnomaly` and `AnomalyReason`, persist all changes

## 7. UrbanManagement — UI

- [x] 7.1 Add `AnomalyReason` column to `WeighingRecord.razor` list table, displaying the value for anomalous records and `--` for normal records
- [x] 7.2 Add edit history display section in `WeighingApproval.razor` approval dialog: deserialize `EditHistoryJson` and render as a timeline showing field, old value, new value, and timestamp for each entry; show "暂无修改记录" when empty
