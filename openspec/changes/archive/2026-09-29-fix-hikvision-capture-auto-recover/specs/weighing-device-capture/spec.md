## ADDED Requirements

### Requirement: Batch capture retries once after SDK soft reset

When `WeighingCaptureService` (or the Hikvision batch API it calls) obtains a batch result with no successful photos, the system SHALL allow one in-call retry after HCNetSDK soft reset per `hikvision-session-lifecycle`. The service SHALL still return only successfully captured file paths and MUST NOT abort the weighing flow when both attempts fail.

#### Scenario: Soft reset retry recovers photos
- **WHEN** the first batch attempt fails for all cameras and soft reset + retry succeeds for some cameras
- **THEN** SHALL return the successful file paths from the retry
- **AND** SHALL log that recovery occurred via soft reset retry

#### Scenario: Soft reset retry still fails
- **WHEN** the first batch and the post-reset retry both return zero successes
- **THEN** SHALL return an empty list
- **AND** SHALL log warnings for failed devices without throwing to the weighing state machine
