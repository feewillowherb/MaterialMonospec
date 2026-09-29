## Purpose

Defines session lifecycle management for Hikvision device connections, including post-capture cleanup, substream capture cleanup, and pre-login logout checks to prevent session leaks.
## Requirements
### Requirement: Post-capture session cleanup

After every mainstream capture attempt (success, failure, or fallback), the system SHALL call `NET_DVR_Logout` with the device's `userId` and remove the entry from `deviceKeyToUserId` cache.

#### Scenario: Mainstream capture succeeds, session cleaned up
- **WHEN** mainstream capture completes successfully
- **THEN** the system SHALL call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId`

#### Scenario: Mainstream capture fails, fallback succeeds, session cleaned up
- **WHEN** mainstream capture fails and the fallback device-side JPEG capture succeeds
- **THEN** the system SHALL call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId`

#### Scenario: All capture attempts fail, session cleaned up
- **WHEN** both mainstream capture and fallback fail
- **THEN** the system SHALL still call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId`

#### Scenario: Exception during capture, session cleaned up
- **WHEN** an unexpected exception occurs during mainstream capture
- **THEN** the system SHALL still call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId` (via try/finally)

### Requirement: Substream capture session cleanup

After every substream capture attempt via `CaptureJpegBatchInternalAsync`, the system SHALL call `NET_DVR_Logout` and clear the local cache entry for the device.

#### Scenario: Substream capture succeeds, session cleaned up
- **WHEN** substream capture completes successfully
- **THEN** the system SHALL call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId`

#### Scenario: Substream capture fails, session cleaned up
- **WHEN** substream capture fails
- **THEN** the system SHALL still call `NET_DVR_Logout(userId)` and evict the device key from `deviceKeyToUserId`

### Requirement: Pre-login logout check

Before attempting a new login, the system SHALL check if a valid `userId` (>= 0) already exists in the cache for the device. If one exists, the system SHALL call `NET_DVR_Logout` on the cached `userId` before proceeding with a fresh login.

#### Scenario: Cached userId exists, logout before re-login
- **WHEN** `EnsureLogin` is called and the cache contains a valid `userId` (>= 0)
- **THEN** the system SHALL call `NET_DVR_Logout(cachedUserId)` and remove the entry from the cache
- **AND** then proceed with a fresh login

#### Scenario: No cached userId or cache has -1
- **WHEN** `EnsureLogin` is called and the cache does not contain a valid `userId`
- **THEN** the system SHALL proceed with login directly without calling logout

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

### Requirement: Long-lived Hikvision login session

The system MUST keep at most one active HCNetSDK login session per device identity key (same IP, port, and username) for MaterialClient Hikvision consumers (LPR and monitoring capture). The session MUST be acquired at LPR startup (or first need) and reused for `ContinuousShoot` and online checks. The system MUST NOT call `NET_DVR_Login_*` solely to probe online status and then immediately `NET_DVR_Logout`.

#### Scenario: Trigger capture reuses cached user id

- **WHEN** a Hikvision LPR device already has a valid cached `userId`
- **AND** the operator triggers active capture
- **THEN** the system SHALL call `ContinuousShoot` with that cached `userId`
- **AND** SHALL NOT perform a redundant Login for that device unless the session was invalidated

#### Scenario: Stop releases LPR listen and sessions

- **WHEN** the Hikvision LPR service stops
- **THEN** the system SHALL stop `StartListen` if running
- **AND** SHALL release or log out LPR-held sessions according to the shared session store rules
- **AND** SHALL NOT leave Listen marked running with a stale handle after stop

### Requirement: Online check uses lightweight probe without login churn

When a cached `userId` exists, online verification MUST call `NET_DVR_RemoteControl` with command `NET_DVR_CHECK_USER_STATUS` (`20005` as defined in HCNetSDK V6.1.9.48). Probe success MUST refresh a last-probed timestamp. Probe failure MUST invalidate the cached session before any re-login. Probes MUST be throttled (default 30 seconds) so repeated UI online checks do not open a new TCP login each time. The system MUST NOT use Login followed by Logout as the online check. Alternate probes such as `GetDVRWORKSTATE` or `GetDVRConfig` MUST NOT be the default path for this change.

#### Scenario: Online check with warm cache skips login

- **WHEN** a valid cached `userId` exists
- **AND** the last successful probe was within the throttle window
- **THEN** `IsOnline` (or equivalent) SHALL report online without calling `NET_DVR_Login_*`

#### Scenario: CHECK_USER_STATUS probe succeeds

- **WHEN** a cached `userId` exists
- **AND** the throttle window has elapsed
- **AND** `NET_DVR_RemoteControl(userId, NET_DVR_CHECK_USER_STATUS, …)` returns success
- **THEN** the system SHALL treat the session as valid
- **AND** SHALL refresh the last-probed timestamp
- **AND** SHALL NOT call `NET_DVR_Logout` as part of the check

#### Scenario: Failed probe invalidates then may re-login once

- **WHEN** `NET_DVR_RemoteControl` with `NET_DVR_CHECK_USER_STATUS` fails with a session/network style error
- **THEN** the system SHALL invalidate that cached `userId`
- **AND** MAY perform at most one Login to recover
- **AND** MUST NOT implement online check as Login followed immediately by Logout on success

### Requirement: Soft-reset clears sessions and rebuilds LPR listen

After HCNetSDK soft-reset (`Cleanup` + re-`Init`), the system MUST invalidate all shared Hikvision login sessions and MUST rebuild LPR `StartListen` (stop stale handle, then start again on the configured listen host/port). The system MUST NOT continue treating a pre-reset listen handle as valid.

#### Scenario: Soft-reset then listen is restarted

- **WHEN** monitoring capture soft-reset completes successfully
- **THEN** cached Hikvision `userId` values SHALL be cleared
- **AND** LPR listen SHALL be restarted so a new listen handle is obtained
- **AND** subsequent LPR capture SHALL acquire a fresh login via the session store

### Requirement: Warn when ContinuousShoot has no plate callback

After `ContinuousShoot` is accepted, if no related plate/alarm callback is observed within a short timeout window (default on the order of 3–5 seconds), the system MUST log a Warning that the shoot command succeeded but no listen callback arrived. This MUST NOT change the success semantics of accepting the shoot command itself.

#### Scenario: Shoot accepted but no callback within timeout

- **WHEN** `ContinuousShoot` returns success
- **AND** no plate/ITS callback for that capture window arrives before the timeout
- **THEN** the system SHALL write a Warning log indicating missing callback
- **AND** SHALL still treat the shoot API call as accepted

### Requirement: Arming APIs are out of scope for this change

This capability MUST NOT require `NET_DVR_SetupAlarmChan_V50`, `NET_DVR_CloseAlarmChan_V30`, or `NET_DVR_SetDVRMessageCallBack_V31` for session lifecycle correctness. Startup and recovery paths defined here MUST remain Listen + login-session based only.

#### Scenario: Session recovery without SetupAlarmChan

- **WHEN** the application starts Hikvision LPR after this change
- **THEN** the system SHALL establish listen and login session lifecycle as specified above
- **AND** SHALL NOT call SetupAlarmChan as part of that lifecycle

