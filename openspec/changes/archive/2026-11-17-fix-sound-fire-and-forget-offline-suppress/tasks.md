## 1. SoundDeviceService — offline suppress and retries

- [x] 1.1 Add last-known online state on `SoundDeviceService`; update it from `IsOnlineAsync` results and from play success / exhausted failure
- [x] 1.2 In `PlayTextV2Async`, when last known online is `false`, log suppress and return without HTTP
- [x] 1.3 Lower production play `maxRetries` from 8 to 3 (both play code paths if both still live)
- [x] 1.4 Make `PlayTextV2TestAsync` force an attempt even when last known online is `false`, still capped at 3 retries

## 2. AttendedWeighing — fire-and-forget announcements

- [x] 2.1 Remove status-transition audio from `EnqueueAsyncOperation`; schedule `PlayTextV2Async` as fire-and-forget with exception logging
- [x] 2.2 Confirm no other weighing path still enqueues `PlayTextV2Async` onto the Merge(5) queue

## 3. Tests

- [x] 3.1 Unit test: last known offline → `PlayTextV2Async` does not call HTTP / returns quickly
- [x] 3.2 Unit test: exhausted 3 retries sets last known offline and subsequent play is suppressed
- [x] 3.3 Unit test: status transition schedules announcement without adding a weighing-queue operation that awaits play (or equivalent: create/reset not blocked by a hanging play mock)
- [x] 3.4 Unit test: `PlayTextV2TestAsync` still attempts when last known offline

## 4. Verification

- [x] 4.1 Run affected MaterialClient.Common.Tests filter for sound / attended weighing announcement changes
- [x] 4.2 Spot-check: with sound mock offline, stabilize flow still creates record without waiting for play retries
