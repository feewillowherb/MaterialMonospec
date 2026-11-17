## ADDED Requirements

### Requirement: Suppress production playback when last known offline

`SoundDeviceService.PlayTextV2Async` SHALL skip HTTP playback when the service's last known online state is offline, and SHALL return without throwing.

#### Scenario: Offline suppress skips HTTP
- **WHEN** last known online state is `false`
- **AND** a caller invokes `PlayTextV2Async` for a status announcement
- **THEN** the service SHALL NOT send HTTP play requests
- **AND** SHALL return promptly
- **AND** SHALL log that playback was suppressed due to offline state

#### Scenario: Unknown online state allows first attempt
- **WHEN** last known online state has never been set
- **AND** a caller invokes `PlayTextV2Async`
- **THEN** the service MAY attempt playback (subject to enabled/valid settings)

### Requirement: Update last known online from status and play outcomes

`SoundDeviceService` SHALL maintain a last-known online flag updated by `IsOnlineAsync` results and by production play success/failure.

#### Scenario: IsOnlineAsync writes cache
- **WHEN** `IsOnlineAsync` completes with a boolean result
- **THEN** the service SHALL store that result as last known online state

#### Scenario: Exhausted play retries mark offline
- **WHEN** `PlayTextV2Async` attempts playback and all retries fail
- **THEN** the service SHALL set last known online state to `false`

#### Scenario: Successful play marks online
- **WHEN** `PlayTextV2Async` starts playback successfully
- **THEN** the service SHALL set last known online state to `true`

### Requirement: Cap production play retries at three

When `PlayTextV2Async` does attempt HTTP playback, it SHALL retry at most three times (including the first attempt), with the existing per-request timeout.

#### Scenario: Three failed attempts then stop
- **WHEN** the sound device does not respond
- **AND** `PlayTextV2Async` is not suppressed
- **THEN** the service SHALL attempt at most 3 HTTP play calls
- **AND** SHALL stop without further retries
- **AND** SHALL mark last known online as offline

### Requirement: Settings test may force playback despite offline suppress

`PlayTextV2TestAsync` SHALL still attempt a test play when last known online is offline, so operators can verify wiring from Settings, and SHALL report success or failure to the caller.

#### Scenario: Test button plays while suppressed
- **WHEN** last known online state is `false`
- **AND** the user runs Settings sound test (`PlayTextV2TestAsync`)
- **THEN** the service SHALL attempt playback (max 3 retries)
- **AND** SHALL surface the outcome to the Settings UI path
