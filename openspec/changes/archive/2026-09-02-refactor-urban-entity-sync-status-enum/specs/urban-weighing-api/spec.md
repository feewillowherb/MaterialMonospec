## MODIFIED Requirements

### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity SHALL include sync fields as non-nullable where applicable: `SyncType` and `ClientSyncType` as `SyncStatus` (default `Pending`), `RetryCount` and `ClientRetryCount` as non-nullable `int` (default `0`). Other extended fields remain as currently specified. The entity MUST NOT include `FdBuildLicenseNo` or `SnapImages`.

#### Scenario: Full record creation with sync defaults

- **WHEN** a POST request creates an UrbanWeighingRecord via ReceiveAsync
- **THEN** `SyncType` and `ClientSyncType` MUST default to `SyncStatus.Pending` when not supplied
- **AND** `RetryCount` and `ClientRetryCount` MUST be `0` when not supplied

#### Scenario: SnapImages removed

- **WHEN** the entity is mapped to the database
- **THEN** no `SnapImages` column SHALL exist on the weighing record table

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
- **AND** the existing record's `SyncType` MUST be reset to `SyncStatus.Pending`
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
- **AND** the system MUST NOT insert additional attachment join rows for that existing record

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The receive/output DTOs SHALL expose `SyncType` and `ClientSyncType` as `SyncStatus` and `ClientRetryCount` as non-nullable `int`. JSON serialization for `SyncStatus` MUST use string enum names in API responses.

#### Scenario: DTO round-trip with string sync status in response

- **WHEN** an API returns a weighing record with `SyncType = Success`
- **THEN** the JSON MUST contain `"syncType": "Success"` (camelCase property name)
- **AND** MUST NOT emit numeric `1` for sync status

#### Scenario: Unknown fdBuildLicenseNo in request body is ignored

- **WHEN** a client POST includes `fdBuildLicenseNo` in the JSON body
- **THEN** the request SHALL still succeed if other fields are valid when using Modern receive
- **AND** the record MUST NOT store `fdBuildLicenseNo`
