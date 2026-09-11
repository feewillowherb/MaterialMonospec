## ADDED Requirements

### Requirement: SDK soft reset after total batch capture failure

When a Hikvision JPEG batch capture completes with zero successes and at least one failure, the system SHALL attempt an HCNetSDK soft reset (logout all cached device sessions, `NET_DVR_Cleanup`, clear the process init flag, then `NET_DVR_Init`) and SHALL retry the same batch once within that call, unless a soft reset already succeeded within the configured cooldown window (default 30 seconds). Soft reset MUST be mutually exclusive so concurrent callers do not interleave Cleanup/Init.

#### Scenario: Total failure triggers soft reset and retry
- **WHEN** a batch returns successCount=0 and failCount>0 and no soft reset succeeded in the last 30 seconds
- **THEN** the system SHALL perform soft reset, log the reset duration, and retry the batch once
- **AND** if the retry succeeds for any camera, those paths SHALL be returned as successes

#### Scenario: Cooldown skips repeated Cleanup
- **WHEN** a batch totally fails but a soft reset already succeeded within the last 30 seconds
- **THEN** the system SHALL NOT call `NET_DVR_Cleanup` again for that attempt
- **AND** SHALL log that soft reset was skipped due to cooldown

#### Scenario: Soft reset is serialized
- **WHEN** two batch captures would soft-reset concurrently
- **THEN** only one Cleanup/Init sequence SHALL run at a time
- **AND** the other SHALL wait for the lock or observe cooldown after the first completes

### Requirement: Soft reset clears login cache before Cleanup

Before `NET_DVR_Cleanup`, the system SHALL logout every cached `userId` in `deviceKeyToUserId` and clear the cache so stale handles are not reused after re-Init.

#### Scenario: Cached sessions logged out
- **WHEN** soft reset starts and the cache contains one or more valid userIds
- **THEN** the system SHALL call `NET_DVR_Logout` for each and evacuate the cache before Cleanup
