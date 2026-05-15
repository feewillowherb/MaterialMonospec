# Weighing Device Capture Specification

## Purpose

Manages camera and LPR device capture operations during the attended weighing process. This service handles batch photo capture from configured Hikvision cameras and triggers Vzvision LPR captures at specific weighing phases.

## Requirements

### Requirement: Capture all configured Hikvision cameras

WeighingCaptureService SHALL capture JPEG images from all configured cameras using IHikvisionService.CaptureJpegFromStreamBatchAsync() and return a list of successfully captured file paths.

#### Scenario: Successful batch capture
- **WHEN** 3 cameras are configured and all return success
- **THEN** SHALL return list of 3 file paths

#### Scenario: Partial capture failure
- **WHEN** 3 cameras configured but 1 fails
- **THEN** SHALL return 2 successful paths and log warning for the failed camera

#### Scenario: No cameras configured
- **WHEN** CameraConfigs list is empty
- **THEN** SHALL return empty list and log warning

### Requirement: Save captured photos to application directory

WeighingCaptureService SHALL save captured photos using AttachmentPathUtils.GetLocalStorageAbsolutePath() to ensure photos are stored in the application directory regardless of working directory.

#### Scenario: Photos saved to correct path
- **WHEN** capture is triggered from any working directory (e.g., C:\Windows\System32)
- **THEN** photos SHALL be saved under the application's attachment storage path

### Requirement: Trigger Vzvision LPR capture at specified phases

WeighingCaptureService SHALL trigger Vzvision LPR capture (TriggerCaptureAsync) for all configured LPR devices at specified flow phases (WaitingForStability, WeightStabilized, OffScale), only when:
- SystemSettings.EnableTriggerLprCapture is true
- SystemSettings.LprDeviceType is Vzvision
- IVzvisionLprService is injected (not null)

#### Scenario: Vzvision trigger enabled
- **WHEN** EnableTriggerLprCapture=true, LprDeviceType=Vzvision, and 2 LPR devices configured
- **THEN** SHALL call TriggerCaptureAsync for both devices

#### Scenario: Vzvision trigger disabled
- **WHEN** EnableTriggerLprCapture=false
- **THEN** SHALL skip LPR trigger and log info

#### Scenario: Non-Vzvision LPR device type
- **WHEN** LprDeviceType is Hikvision
- **THEN** SHALL skip Vzvision trigger (return early)

#### Scenario: IVzvisionLprService not injected
- **WHEN** IVzvisionLprService is null
- **THEN** SHALL log warning and skip trigger

### Requirement: Handle individual device capture failures gracefully

WeighingCaptureService SHALL catch exceptions from individual device captures and continue with remaining devices, logging failures without aborting the batch.

#### Scenario: One device throws exception
- **WHEN** TriggerCaptureAsync throws for device A but succeeds for device B
- **THEN** SHALL log warning for device A and return success for device B
