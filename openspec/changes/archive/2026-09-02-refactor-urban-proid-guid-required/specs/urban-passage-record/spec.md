## ADDED Requirements

### Requirement: UrbanPassageRecord ProId is required Guid

`UrbanPassageRecord` SHALL persist `ProId` as a non-nullable `Guid`. Passage create/receive paths MUST supply a valid project id and MUST reject `Guid.Empty`.

#### Scenario: Passage created with valid ProId

- **WHEN** a checkpoint or finished-product passage is created via the Urban receive path
- **THEN** `UrbanPassageRecord.ProId` SHALL be set to the supplied non-empty Guid
- **AND** the value SHALL be persisted as non-nullable

#### Scenario: Passage receive rejects empty ProId

- **WHEN** a passage receive payload omits `proId` or supplies `Guid.Empty`
- **THEN** the system SHALL reject the request
- **AND** MUST NOT insert a passage row
