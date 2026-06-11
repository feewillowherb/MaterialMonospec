## ADDED Requirements

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

#### Scenario: Duplicate receive does not recompute anomaly

- **WHEN** `ReceiveAsync` is called with an existing `ClientRecordId` (idempotent return path)
- **THEN** the system MUST return the existing record without recalculating `IsAnomaly`

## MODIFIED Requirements

### Requirement: Urban weighing record approval API

UrbanManagement SHALL expose an application service method to approve (correct) an existing `UrbanWeighingRecord` by server primary key, aligned with MaterialClient.Urban approval semantics.

#### Scenario: Approve via ABP conventional API

- **WHEN** an authenticated administrator sends `POST /api/app/urban-weighing-record/approve` (ABP conventional route) with a valid body containing `id`, `plateNumber`, and `totalWeight`
- **THEN** the system SHALL invoke `IUrbanWeighingRecordAppService.ApproveAsync`
- **AND** SHALL return the updated record representation (e.g. `UrbanWeighingRecordOutputDto`)

#### Scenario: Record not found

- **WHEN** `ApproveAsync` is called with a non-existent `id`
- **THEN** the system SHALL return an error indicating the record was not found

#### Scenario: Validation failure returns client-aligned errors

- **WHEN** plate validation or weight validation fails
- **THEN** the API SHALL return HTTP 400 with a clear validation message
- **AND** SHALL NOT update the entity

#### Scenario: Non-anomalous record rejected

- **WHEN** `ApproveAsync` is called for a record with `IsAnomaly == false`
- **THEN** the API SHALL return HTTP 400 with a clear message that the record is not eligible for approval
- **AND** SHALL NOT update the entity
