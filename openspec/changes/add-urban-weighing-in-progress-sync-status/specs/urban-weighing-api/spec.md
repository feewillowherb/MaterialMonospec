## MODIFIED Requirements

### Requirement: Client IsAnomaly persisted on receive without server recalculation

When UrbanManagement receives a weighing record from MaterialClient.Urban via `ReceiveAsync`, the system SHALL persist the `IsAnomaly` value from the request DTO and MUST NOT recalculate it using server-side **weight threshold** rules (`UpperLimit` / `LowerLimit` / `DeviationPercentage`). **Empty-plate fallback:** if the persisted plate number is null or whitespace, the system MUST set `IsAnomaly` to `true` and set `AnomalyReason` to the empty-plate reason text (aligned with client, e.g. 「车牌为空」), even when the client sent `isAnomaly: false`.

#### Scenario: Receive preserves client anomaly flag true

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: true` from the client
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `true`
- **AND** no server weight-threshold anomaly detector MUST be invoked

#### Scenario: Receive preserves client anomaly flag false when plate present

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: false` and a non-whitespace `PlateNumber`
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `false`
- **AND** no server weight-threshold anomaly detector MUST be invoked

#### Scenario: Receive forces anomaly when plate empty

- **WHEN** `ReceiveAsync` receives a new or duplicate record whose `PlateNumber` is null or whitespace
- **THEN** the stored `UrbanWeighingRecord.IsAnomaly` MUST be `true`
- **AND** `AnomalyReason` MUST be the empty-plate reason text
- **AND** this MUST apply even if the payload has `isAnomaly: false`
- **AND** MUST NOT invoke weight upper/lower/deviation recalculation

#### Scenario: Duplicate receive updates anomaly from client payload when plate present

- **WHEN** `ReceiveAsync` is called with an existing `ClientRecordId` (idempotent return path)
- **AND** the payload contains a non-whitespace `PlateNumber` and `isAnomaly: false` while the stored record has `IsAnomaly: true`
- **THEN** the system MUST update the stored record's `IsAnomaly` to `false` from the payload
- **AND** MUST NOT invoke server-side weight-threshold anomaly recalculation
- **AND** MUST return the existing record Id

#### Scenario: Duplicate receive cannot clear anomaly with empty plate

- **WHEN** `ReceiveAsync` is called with an existing `ClientRecordId`
- **AND** the payload has empty/whitespace `PlateNumber` and `isAnomaly: false`
- **THEN** the stored record MUST remain or become `IsAnomaly = true` with empty-plate reason
