## MODIFIED Requirements

### Requirement: No new GovSyncData inserts

After entity semantic hardening, the system MUST NOT insert new rows into `GovSyncData`. Modern weighing receive, Legacy weighing ingest (success and reject staging), and any remaining stubs MUST NOT call `InsertAsync` on `GovSyncData`. Existing historical rows MAY remain read-only.

#### Scenario: Modern receive does not dual-write

- **WHEN** `UrbanWeighingRecordAppService.ReceiveAsync` creates or updates a record
- **THEN** the system MUST NOT insert or update `GovSyncData` for that operation

#### Scenario: Legacy ingest does not write GovSyncData

- **WHEN** a client calls the Legacy HTTP endpoint and ingest succeeds or is rejected into staging
- **THEN** the system MUST NOT insert into `GovSyncData`
