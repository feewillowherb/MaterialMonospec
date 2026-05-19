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
