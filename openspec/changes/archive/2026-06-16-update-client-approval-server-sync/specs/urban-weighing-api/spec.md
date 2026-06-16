## MODIFIED Requirements

### Requirement: ClientRecordId idempotency

The system SHALL enforce uniqueness on `ClientRecordId`. If a record with the same `ClientRecordId` already exists, the system SHALL return the existing record's ID without creating a duplicate, and SHALL apply upsert updates to the existing record's correctable fields from the incoming DTO.

#### Scenario: First submission

- **WHEN** a record with `ClientRecordId: 12345` is submitted and no record with that ID exists
- **THEN** a new record SHALL be created and its ID returned

#### Scenario: Duplicate submission with corrected fields

- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload contains updated `plateNumber`, `totalWeight`, and `isAnomaly: false`
- **THEN** the existing record's ID SHALL be returned
- **AND** no new record SHALL be created
- **AND** the existing record's `PlateNumber` and `TotalWeight` MUST reflect the payload values
- **AND** the existing record's `IsAnomaly` MUST be `false`
- **AND** the existing record's `SyncType` MUST be reset to `0`
- **AND** the existing record's `RetryCount` MUST be reset to `0`

#### Scenario: Duplicate submission idempotent retry

- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload fields match the stored values
- **THEN** the existing record's ID SHALL be returned
- **AND** no duplicate record SHALL be created

#### Scenario: Duplicate submission ignores attachment updates

- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload includes `attachmentIds` with one or more Guids
- **THEN** the existing record's attachment associations MUST remain unchanged
- **AND** the system MUST NOT insert additional `UrbanWeighingRecordAttachment` rows for that existing record

### Requirement: Client IsAnomaly persisted on receive without server recalculation

When UrbanManagement receives a weighing record from MaterialClient.Urban via `ReceiveAsync`, the system SHALL persist the `IsAnomaly` value from the request DTO and MUST NOT recalculate it using server-side threshold rules.

#### Scenario: Receive preserves client anomaly flag true

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: true` from the client
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `true`
- **AND** no server anomaly detector MUST be invoked

#### Scenario: Receive preserves client anomaly flag false

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: false` from the client
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `false`
- **AND** no server anomaly detector MUST be invoked

#### Scenario: Duplicate receive updates anomaly from client payload

- **WHEN** `ReceiveAsync` is called with an existing `ClientRecordId` (idempotent return path)
- **AND** the payload contains `isAnomaly: false` while the stored record has `IsAnomaly: true`
- **THEN** the system MUST update the stored record's `IsAnomaly` to `false` from the payload
- **AND** MUST NOT invoke server-side anomaly recalculation
- **AND** MUST return the existing record Id
