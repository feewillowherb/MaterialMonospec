## MODIFIED Requirements

### Requirement: Append edit entry on approval

The system SHALL append an edit entry to `EditHistoryJson` when `PlateNumber` or `TotalWeight` is modified during the approval process, and SHALL set `IsImagesModified` to `true` on the new edit entry when Lrp image modification occurred during the same approval. Lrp modification includes file-picker replacement and adopting UrbanPhoto as Lrp; the system SHALL NOT distinguish these cases in edit history.

On **UrbanManagement Web**, Lrp modification is detected when `ApproveAsync` receives non-null, non-empty `LrpReplacementBase64`. On **MaterialClient**, Lrp modification is detected when local Lrp attachment was created or replaced during the approval dialog session before Save.

#### Scenario: PlateNumber change recorded

- **WHEN** approval modifies `PlateNumber` and the new value differs from the old value
- **THEN** the system SHALL append an edit entry with `field = "PlateNumber"`, `oldValue = <old plate>`, `newValue = <new plate>`, `changedAt = <current UTC time>`

#### Scenario: TotalWeight change recorded

- **WHEN** approval modifies `TotalWeight` and the new value differs from the old value
- **THEN** the system SHALL append an edit entry with `field = "TotalWeight"`, `oldValue = <old weight>`, `newValue = <new weight>`, `changedAt = <current UTC time>`

#### Scenario: Both fields changed in single approval

- **WHEN** approval modifies both `PlateNumber` and `TotalWeight`
- **THEN** the system SHALL append two edit entries in a single write
- **AND** the order SHALL be PlateNumber first, then TotalWeight

#### Scenario: No field change produces no entry

- **WHEN** approval is completed but neither `PlateNumber` nor `TotalWeight` differs from the current values and no Lrp image modification occurred
- **THEN** no edit entry SHALL be appended
- **AND** `EditHistoryJson` SHALL remain unchanged

#### Scenario: Web Lrp image modification marks IsImagesModified

- **WHEN** `ApproveAsync` processes Lrp image modification (non-null, non-empty `LrpReplacementBase64`)
- **AND** an edit entry is appended to the history
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `true`
- **AND** the edit entry SHALL NOT contain a separate field indicating adopt versus replace

#### Scenario: Client local Lrp adopt or replace marks IsImagesModified

- **WHEN** MaterialClient approval Save occurs after local Lrp was created (adopt from UrbanPhoto) or replaced (file picker) in the same dialog session
- **AND** an edit entry is appended via `AppendEditEntryAsync` or equivalent
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `true`
- **AND** the edit entry SHALL NOT distinguish adopt from file replace

#### Scenario: No Lrp image modification keeps IsImagesModified false

- **WHEN** approval completes without Web `LrpReplacementBase64` and without client local Lrp create/replace
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `false`
