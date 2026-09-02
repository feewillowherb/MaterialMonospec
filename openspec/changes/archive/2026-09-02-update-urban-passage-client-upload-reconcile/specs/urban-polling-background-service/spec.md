## ADDED Requirements

### Requirement: Poll pending passage records for upload

`PollingBackgroundService` SHALL scan pending `UrbanPassageRecord` rows in addition to weighing extensions and invoke `IUrbanPassageUploadService.SubmitPassageRecordAsync` for each pending passage row within the configured batch size. Weighing upload behavior MUST remain unchanged.

#### Scenario: Passage batch in polling cycle

- **WHEN** a polling cycle runs and pending passage rows exist
- **THEN** the worker MUST attempt upload for each pending passage row up to `Urban:UploadBatchSize`
- **AND** MUST continue with remaining rows on single-row failure

### Requirement: Immediate upload on passage create

MaterialClient.Urban SHALL handle `UrbanPassageRecordCreatedEventData` with a background handler that attempts immediate `SubmitPassageRecordAsync` for the new row, mirroring the weighing immediate-upload pattern. The handler MUST NOT block the LPR event thread on HTTP.

#### Scenario: Create triggers upload attempt

- **WHEN** a passage row is created from LPR capture
- **THEN** an event handler MUST enqueue or run upload for that `PassageRecordId`
- **AND** on failure the row MUST remain Pending for polling retry
