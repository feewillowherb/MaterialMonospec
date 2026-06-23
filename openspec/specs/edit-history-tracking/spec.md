# edit-history-tracking Specification

## Purpose
TBD - created by archiving change anomaly-reason-repair-history. Update Purpose after archive.
## Requirements
### Requirement: EditHistoryJson persistent field
The system SHALL persist `EditHistoryJson` as a `string?` property on `UrbanWeighingExtension` (MaterialClient) and `UrbanWeighingRecord` (UrbanManagement). The value SHALL contain a JSON array of edit entry objects.

#### Scenario: EditHistoryJson column schema
- **WHEN** the entity table is configured
- **THEN** `EditHistoryJson` SHALL be stored as a nullable text/JSON column
- **AND** the default value SHALL be `null` (no history)

#### Scenario: EditHistoryJson data structure
- **WHEN** `EditHistoryJson` contains data
- **THEN** it SHALL be a valid JSON array
- **AND** each element SHALL contain `field` (string), `oldValue` (string), `newValue` (string), and `changedAt` (ISO 8601 datetime string)

### Requirement: EditEntry computed property
The system SHALL expose a `[NotMapped]` computed property `EditHistory` that serializes/deserializes `EditHistoryJson` to a `List<EditEntry>`, following the existing `Materials` / `MaterialsJson` pattern.

#### Scenario: Deserialize EditHistoryJson
- **WHEN** `EditHistory` getter is accessed and `EditHistoryJson` contains valid JSON
- **THEN** the system SHALL deserialize it to `List<EditEntry>`
- **AND** if deserialization fails, it SHALL return an empty list (not throw)

#### Scenario: Serialize EditHistory
- **WHEN** `EditHistory` setter is called with a non-empty list
- **THEN** the system SHALL serialize the list to JSON and assign to `EditHistoryJson`
- **AND** if the list is null or empty, `EditHistoryJson` SHALL be set to `null`

### Requirement: Append edit entry on approval
The system SHALL append a edit entry to `EditHistoryJson` when `PlateNumber` or `TotalWeight` is modified during the approval process, and SHALL set `IsImagesModified` to `true` on the new edit entry when any image replacement occurred during the same approval.

#### Scenario: PlateNumber change recorded
- **WHEN** `ApproveAsync` modifies `PlateNumber` and the new value differs from the old value
- **THEN** the system SHALL append a edit entry with `field = "PlateNumber"`, `oldValue = <old plate>`, `newValue = <new plate>`, `changedAt = <current UTC time>`

#### Scenario: TotalWeight change recorded
- **WHEN** `ApproveAsync` modifies `TotalWeight` and the new value differs from the old value
- **THEN** the system SHALL append a edit entry with `field = "TotalWeight"`, `oldValue = <old weight>`, `newValue = <new weight>`, `changedAt = <current UTC time>`

#### Scenario: Both fields changed in single approval
- **WHEN** `ApproveAsync` modifies both `PlateNumber` and `TotalWeight`
- **THEN** the system SHALL append two edit entries in a single write
- **AND** the order SHALL be PlateNumber first, then TotalWeight

#### Scenario: No change produces no entry
- **WHEN** `ApproveAsync` is called but neither `PlateNumber` nor `TotalWeight` differs from the current values
- **THEN** no edit entry SHALL be appended
- **AND** `EditHistoryJson` SHALL remain unchanged

#### Scenario: Image replacement marks IsImagesModified
- **WHEN** `ApproveAsync` processes image replacement (non-null `LrpReplacementBase64` or `UrbanPhotoReplacementBase64`)
- **AND** an edit entry is appended to the history
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `true`

#### Scenario: No image replacement keeps IsImagesModified false
- **WHEN** `ApproveAsync` processes without image replacement (both replacement fields null or empty)
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `false`

### Requirement: MaterialClient service method for edit history
The system SHALL provide an `AppendEditEntryAsync` method on `IUrbanWeighingExtensionService` for writing edit entries on the MaterialClient side.

#### Scenario: AppendEditEntryAsync parameters
- **WHEN** `AppendEditEntryAsync` is called with `extensionId`, `field`, `oldValue`, `newValue`
- **THEN** the system SHALL read the current `EditHistoryJson`
- **AND** deserialize it, append the new entry with `changedAt = DateTime.UtcNow`
- **AND** serialize and persist the updated JSON array

### Requirement: EditHistoryJson synchronized to UrbanManagement server
The system SHALL transmit `EditHistoryJson` from MaterialClient to UrbanManagement via the upload API and persist it on `UrbanWeighingRecord`.

#### Scenario: ReceiveAsync persists EditHistoryJson
- **WHEN** `ReceiveAsync` receives a record with a non-null `EditHistoryJson`
- **THEN** the system SHALL store the value on `UrbanWeighingRecord.EditHistoryJson`
- **AND** the value SHALL be persisted to the database

#### Scenario: ReceiveAsync handles null EditHistoryJson
- **WHEN** `ReceiveAsync` receives a record with `EditHistoryJson == null`
- **THEN** the system SHALL store `null`
- **AND** no error SHALL be thrown

### Requirement: Edit history displayed in UrbanManagement approval UI
The system SHALL display the edit history in the UrbanManagement approval dialog.

#### Scenario: Edit history shown in approval dialog
- **WHEN** the approval dialog opens for a record with non-empty `EditHistoryJson`
- **THEN** the system SHALL display the edit history as a timeline list showing field name, old value, new value, and timestamp for each entry

#### Scenario: No history for unmodified records
- **WHEN** the approval dialog opens for a record with `EditHistoryJson == null` or empty array
- **THEN** the edit history section SHALL display a message indicating no modifications have been made (e.g., "暂无修改记录")

