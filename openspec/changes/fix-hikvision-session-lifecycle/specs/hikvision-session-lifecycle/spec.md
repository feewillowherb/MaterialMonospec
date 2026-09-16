## ADDED Requirements

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
