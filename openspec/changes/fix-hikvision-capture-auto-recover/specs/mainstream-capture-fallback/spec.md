## ADDED Requirements

### Requirement: Decoder init timeout triggers device-side JPEG fallback

When mainstream `CaptureJpegFromStream` fails because the PlayM4 decoder did not reach playing state within the wait timeout (including no `NET_DVR_SYSHEAD` received), the Mainstream batch path SHALL treat this as a mainstream failure and SHALL attempt device-side `CaptureJpeg` fallback per existing fallback rules.

#### Scenario: Timeout then fallback succeeds
- **WHEN** `WaitForPlaying` times out and device-side JPEG capture succeeds
- **THEN** the batch result SHALL have `Success=true` and `FallbackUsed=true`

#### Scenario: Timeout then fallback fails
- **WHEN** `WaitForPlaying` times out and device-side JPEG capture also fails
- **THEN** the batch result SHALL have `Success=false`
- **AND** the error message SHALL include mainstream timeout context and fallback HCNetSDK error

### Requirement: Decoder timeout diagnostics distinguish missing SYSHEAD

When `WaitForPlaying` times out, the system SHALL log a structured reason: `no_syshead` when the decoder never acquired a PlayM4 port / never initialized from system header; otherwise the real PlayM4 error from a valid port. The system MUST NOT present `PlayM4_GetLastError` on port `-1` (commonly code 32) as the root cause of a missing SYSHEAD timeout.

#### Scenario: Timeout before port acquisition
- **WHEN** WaitForPlaying times out and decoder port is still unassigned
- **THEN** the system SHALL log reason `no_syshead` (or equivalent)
- **AND** SHALL NOT attribute the failure solely to PlayM4 error 32

#### Scenario: Timeout after OpenStream failure
- **WHEN** WaitForPlaying times out after a failed OpenStream/Play on a valid port
- **THEN** the system SHALL log the PlayM4 last error from that port
