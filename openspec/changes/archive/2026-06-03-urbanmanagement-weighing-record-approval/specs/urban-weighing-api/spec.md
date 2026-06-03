## ADDED Requirements

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
