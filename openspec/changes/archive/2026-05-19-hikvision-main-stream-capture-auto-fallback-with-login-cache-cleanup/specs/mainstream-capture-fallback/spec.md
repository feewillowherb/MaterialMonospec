## ADDED Requirements

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
