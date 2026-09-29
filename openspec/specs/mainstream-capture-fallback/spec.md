## Purpose

Defines the automatic fallback behavior when mainstream stream capture fails, including device-side JPEG capture as an alternative, logging, and result indication.
## Requirements
### Requirement: Automatic fallback to device-side JPEG on mainstream capture failure

When `CaptureJpegFromStreamBatchAsync` is called with `StreamType.Mainstream` and the mainstream capture (`CaptureJpegFromStream`) fails for a request, the system SHALL automatically attempt device-side JPEG capture (`CaptureJpeg`) using the same device config, channel, save path, and `jpegQuality` parameter.

#### Scenario: Mainstream capture fails, fallback succeeds
- **WHEN** mainstream capture returns `Success=false` for a request
- **THEN** the system SHALL call `CaptureJpeg` with the same `config`, `channel`, `saveFullPath`, and `jpegQuality`
- **AND** if `CaptureJpeg` succeeds, the result SHALL have `Success=true` and `FallbackUsed=true`

#### Scenario: Mainstream capture fails, fallback also fails
- **WHEN** mainstream capture returns `Success=false` and the fallback `CaptureJpeg` also fails
- **THEN** the result SHALL have `Success=false` with error messages from both attempts
- **AND** `FallbackUsed` SHALL be `false`

#### Scenario: Mainstream capture succeeds
- **WHEN** mainstream capture returns `Success=true`
- **THEN** no fallback SHALL be attempted
- **AND** the result SHALL have `FallbackUsed=false`

### Requirement: Fallback captures use identical output parameters

The fallback `CaptureJpeg` call SHALL use the same `channel`, `saveFullPath`, and `jpegQuality` as the original mainstream capture request.

#### Scenario: Parameter consistency
- **WHEN** fallback is triggered for a request with `channel=1`, `saveFullPath="/photos/cam1.jpg"`, `jpegQuality=85`
- **THEN** the fallback `CaptureJpeg` SHALL be called with `channel=1`, `saveFullPath="/photos/cam1.jpg"`, `jpegQuality=85`

### Requirement: Fallback events are logged

The system SHALL log fallback attempts with both the mainstream error codes and the fallback result for operational observability.

#### Scenario: Fallback attempt logged
- **WHEN** mainstream capture fails and fallback is attempted
- **THEN** the system SHALL log a warning including the device IP, channel, mainstream error codes (`HcNetSdkError`, `PlayM4Error`), and whether the fallback succeeded

### Requirement: BatchCaptureResult includes fallback indicator

`BatchCaptureResult` SHALL include a `FallbackUsed` property to indicate whether the capture succeeded via the device-side JPEG fallback path.

#### Scenario: Result indicates fallback was used
- **WHEN** mainstream capture fails and the device-side JPEG fallback succeeds
- **THEN** `BatchCaptureResult.FallbackUsed` SHALL be `true`

#### Scenario: Result indicates no fallback
- **WHEN** mainstream capture succeeds without fallback
- **THEN** `BatchCaptureResult.FallbackUsed` SHALL be `false`

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

