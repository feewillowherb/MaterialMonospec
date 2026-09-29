## ADDED Requirements

### Requirement: UrbanWeighingRecord IngestSource

The `UrbanWeighingRecord` entity SHALL expose non-nullable `IngestSource` of type `UrbanWeighingIngestSource` with values `Modern = 0`, `Legacy = 1`, `Migrated = 2`, default `Modern`. The database column MUST store the enum as an integer. Historical rows MUST migrate to `Modern` (0). `SubmitMachineCode` MUST NOT be used to encode ingest channel.

#### Scenario: Legacy path persists Legacy

- **WHEN** a weighing record is created through the Legacy ingest path
- **THEN** `UrbanWeighingRecord.IngestSource` SHALL equal `UrbanWeighingIngestSource.Legacy`

#### Scenario: Modern Receive forces Modern

- **WHEN** `ReceiveAsync` is invoked from the modern ABP receive API
- **THEN** the persisted `IngestSource` MUST be `Modern`
- **AND** any client-supplied ingest source value MUST be ignored for persistence

#### Scenario: Migrated value reserved

- **WHEN** the enum is defined
- **THEN** `Migrated = 2` SHALL exist as a reserved value
- **AND** this change MUST NOT write `Migrated` on the live Legacy or Modern receive paths
