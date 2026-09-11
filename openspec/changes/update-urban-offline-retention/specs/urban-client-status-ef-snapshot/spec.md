## ADDED Requirements

### Requirement: Daily Redis-to-EF client status snapshot

UrbanManagement SHALL run a periodic background job (default approximately once per 24 hours, configurable) that reads live connection state from Redis and upserts corresponding `ClientOnlineStatus` rows in EF. The SignalR connect / disconnect / `UploadStatus` hot paths MUST NOT perform these EF upserts.

#### Scenario: Daily snapshot upserts connection rows

- **WHEN** the snapshot worker runs and Redis contains connection entries
- **THEN** the system SHALL upsert `ClientOnlineStatus` for each `(ProId, ClientId)` from Redis (including offline entries still within retention)
- **AND** SHALL copy connected/offline flags and relevant timestamps into EF
- **AND** SHALL NOT run that upsert on the Hub disconnect hot path

#### Scenario: Snapshot failures are observable

- **WHEN** the snapshot worker fails (Redis or EF error)
- **THEN** the failure SHALL be logged
- **AND** the Hub live path SHALL continue to operate without requiring EF

#### Scenario: Optional device-detail snapshot

- **WHEN** device current-state entries exist in Redis for snapshotted instances
- **THEN** the worker MAY upsert matching `ClientDeviceOnlineStatus` (or equivalent) rows
- **AND** if device snapshot is enabled, it SHALL likewise stay off the SignalR hot path
