## ADDED Requirements

### Requirement: Weighbridge dataSource prefers mode settings

When mapping Weighbridge mode, MaterialClient SHALL resolve `dataSource` from the mode’s settings envelope when that value is non-empty, otherwise SHALL use the default `WEIGHBRIDGE_XIAOSHAN`. This SHALL match UrbanManagement mapping behavior.

#### Scenario: Mode settings dataSource used

- **WHEN** field mapping runs for Weighbridge
- **AND** the Weighbridge mode settings include a non-empty `dataSource`
- **THEN** the resolved output SHALL use that `dataSource`

#### Scenario: Default dataSource when mode value empty

- **WHEN** field mapping runs for Weighbridge
- **AND** the Weighbridge mode settings omit `dataSource` or it is empty
- **THEN** the resolved output SHALL use `WEIGHBRIDGE_XIAOSHAN`
