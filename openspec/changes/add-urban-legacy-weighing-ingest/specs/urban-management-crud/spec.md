## MODIFIED Requirements

### Requirement: Legacy API compatibility

The system SHALL maintain compatibility with the legacy government client API through `LegacyApiController` at `POST /Api/Post`. The controller SHALL parse the legacy JSON body, delegate to `ILegacyGovSyncAppService`, and return `{ success, msg, code }` without requiring authentication. `LegacyGovSyncAppService` SHALL implement real ingest into `UrbanWeighingRecord` (and reject staging on failure) as specified by `urban-legacy-weighing-ingest`. The endpoint MUST NOT remain a permanent WIP that always returns HTTP 501 after this change is applied.

#### Scenario: Legacy request processing

- **WHEN** a legacy client submits a request to `/Api/Post`
- **THEN** `LegacyApiController` SHALL receive the request
- **AND** SHALL delegate processing to `LegacyGovSyncAppService`
- **AND** SHALL return a response in the legacy `{ success, msg, code }` format

#### Scenario: Legacy sync result format

- **WHEN** `LegacyGovSyncAppService` processes a request
- **THEN** it SHALL return a result with success flag, message, and status code compatible with existing clients
- **AND** on successful ingest `code` SHALL be 200 and `success` SHALL be true

#### Scenario: No permanent WIP 501 after implementation

- **WHEN** this change is deployed and a valid legacy weighing payload is posted
- **THEN** the system MUST NOT respond with HTTP 501 solely due to a WIP stub
