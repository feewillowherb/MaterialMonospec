## MODIFIED Requirements

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
