## MODIFIED Requirements

### Requirement: Legacy API endpoint accepts old GovClient POST requests

The system SHALL keep the route `POST /Api/Post` for backward-compatible routing discovery. The endpoint SHALL NOT persist weighing data or `GovSyncData`. The endpoint MUST respond with HTTP status **501 Not Implemented** and a legacy-shaped body `{ "success": false, "msg": "WIP: legacy endpoint unavailable", "code": 501, "data": null }`. Implementation MUST be marked WIP; full compatibility is deferred to [INT-006](../../../../docs/intake/2026-09/INT-006-legacy-gov-sync-reimplementation.md).

#### Scenario: Legacy POST does not persist

- **WHEN** a POST request is sent to `/Api/Post` with a previously valid legacy JSON body
- **THEN** the system MUST NOT insert or update `UrbanWeighingRecord` or `GovSyncData`
- **AND** MUST respond with HTTP 501 and the WIP message body

#### Scenario: fdBuildLicenseNo in body is ignored

- **WHEN** a legacy POST includes `fdBuildLicenseNo` in the JSON body
- **THEN** the system MUST NOT validate or persist that field
- **AND** MUST still return the WIP 501 response without side effects

## REMOVED Requirements

### Requirement: Dual access-code validation

**Reason**: Legacy persistence removed; validation deferred to INT-006 reimplementation.

**Migration**: Use Modern `UrbanWeighingRecord` receive API or wait for Legacy refactor (INT-006).

### Requirement: grossWeight overrides goodsWeight

**Reason**: No `GovSyncData` writes on Legacy path.

**Migration**: N/A for Legacy until INT-006.

### Requirement: Source data preservation

**Reason**: No `GovSyncData` writes on Legacy path.

**Migration**: Historical `GovSyncData` rows remain read-only.
