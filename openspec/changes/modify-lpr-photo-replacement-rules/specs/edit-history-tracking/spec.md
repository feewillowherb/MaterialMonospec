## MODIFIED Requirements

### Requirement: Append edit entry on approval

The system SHALL append a edit entry to `EditHistoryJson` when `PlateNumber` or `TotalWeight` is modified during the approval process, and SHALL set `IsImagesModified` to `true` on the new edit entry when a Lrp image replacement occurred during the same approval. The system SHALL set `IsLprAdoptedFromUrbanPhoto` to `true` on the new edit entry when the approval staged an UrbanPhoto-to-Lpr adoption. UrbanPhoto replacement SHALL NOT trigger `IsImagesModified` because UrbanPhoto is no longer replaceable.

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

#### Scenario: Lrp image replacement marks IsImagesModified

- **WHEN** `ApproveAsync` processes Lrp image replacement (non-null, non-empty `LrpReplacementBase64`)
- **AND** an edit entry is appended to the history
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `true`
- **AND** the new `EditEntry.IsLprAdoptedFromUrbanPhoto` SHALL be set to `false`

#### Scenario: Lpr adoption marks IsLprAdoptedFromUrbanPhoto

- **WHEN** `ApproveAsync` processes a Lpr adoption (`AdoptUrbanPhotoAsLpr == true`)
- **AND** an edit entry is appended to the history
- **THEN** the new `EditEntry.IsLprAdoptedFromUrbanPhoto` SHALL be set to `true`
- **AND** the new `EditEntry.IsImagesModified` SHALL be set to `false` (adoption is not a manual image swap)

#### Scenario: No image action keeps both flags false

- **WHEN** `ApproveAsync` processes without Lrp replacement AND without adoption (`LrpReplacementBase64` null/empty AND `AdoptUrbanPhotoAsLpr == false`)
- **THEN** the new `EditEntry.IsImagesModified` SHALL be set to `false`
- **AND** the new `EditEntry.IsLprAdoptedFromUrbanPhoto` SHALL be set to `false`

#### Scenario: Adoption and explicit Lrp replacement are mutually exclusive

- **WHEN** `ApproveAsync` receives both `LrpReplacementBase64` non-empty AND `AdoptUrbanPhotoAsLpr == true`
- **THEN** the system SHALL prioritize the explicit `LrpReplacementBase64` (set `IsImagesModified = true`, `IsLprAdoptedFromUrbanPhoto = false`)
- **OR** the system SHALL reject the request with a validation error
- **AND** the system SHALL NOT simultaneously set both flags to `true` on the same `EditEntry`
