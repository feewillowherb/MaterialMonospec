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

WeighingCaptureService SHALL save captured photos using `AttachmentPathUtils.GetLocalStorageAbsolutePath()` to ensure photos are stored in the application directory regardless of working directory. When `WeighingMode` is UrbanMode (201), SHALL use `AttachType.UrbanPhoto` for the storage path; otherwise SHALL use `AttachType.EntryPhoto` (existing monitoring photo layout).

#### Scenario: Photos saved to correct path
- **WHEN** capture is triggered from any working directory (e.g., C:\Windows\System32)
- **THEN** photos SHALL be saved under the application's attachment storage path for the resolved `AttachType`

#### Scenario: UrbanMode uses UrbanPhoto storage path
- **WHEN** `GetWeighingModeAsync` returns UrbanMode (201) and batch capture runs
- **THEN** SHALL call `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, ...)`
- **AND** saved files SHALL reside under the `PhotoUrban` dated directory tree

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

### Requirement: State transitions follow defined rules

WeighingStateManager SHALL manage an AttendedWeighingStatus state machine with exactly 4 states: OffScale, WaitingForStability, WeightStabilized, WaitingForDeparture. All transitions SHALL follow these rules:
- OffScale + weight > threshold → WaitingForStability
- WaitingForStability + weight < threshold → OffScale (abnormal departure)
- WaitingForStability + stability.IsStable + no existing record → WeightStabilized
- WeightStabilized + existing record → WaitingForDeparture
- WeightStabilized + weight < threshold → OffScale (abnormal)
- WaitingForDeparture + weight < threshold → OffScale (normal completion)

When WeighingMode = UrbanMode (201), the state machine SHALL operate identically but MUST NOT trigger waybill matching logic after record creation.

#### Scenario: Truck drives onto scale
- **WHEN** current state is OffScale and weight exceeds MinWeightThreshold
- **THEN** state SHALL transition to WaitingForStability

#### Scenario: Truck leaves before weight stabilizes
- **WHEN** current state is WaitingForStability and weight drops below MinWeightThreshold
- **THEN** state SHALL transition to OffScale

#### Scenario: Weight stabilizes without existing record
- **WHEN** current state is WaitingForStability, stability.IsStable is true, and no weighing record has been created (lastCreatedWeighingRecordId is null)
- **THEN** state SHALL transition to WeightStabilized

#### Scenario: Record created after stabilization
- **WHEN** current state is WeightStabilized and a weighing record has been created (lastCreatedWeighingRecordId > 0)
- **THEN** state SHALL transition to WaitingForDeparture

#### Scenario: Truck departs normally
- **WHEN** current state is WaitingForDeparture and weight drops below MinWeightThreshold
- **THEN** state SHALL transition to OffScale

#### Scenario: Abnormal departure from WeightStabilized
- **WHEN** current state is WeightStabilized and weight drops below MinWeightThreshold without creating a record
- **THEN** state SHALL transition directly to OffScale

#### Scenario: UrbanMode does not trigger waybill matching
- **WHEN** WeighingMode = UrbanMode (201) and a weighing record is created
- **THEN** SHALL NOT publish TryMatchEvent
- **AND** SHALL NOT enter waybill matching flow
