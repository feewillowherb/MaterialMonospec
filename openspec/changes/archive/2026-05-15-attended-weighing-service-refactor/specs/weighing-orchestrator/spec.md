## ADDED Requirements

### Requirement: Implement IAttendedWeighingService interface
AttendedWeighingOrchestrator SHALL implement IAttendedWeighingService, providing StartAsync(), StopAsync(), GetCurrentStatus(), GetMostFrequentPlateNumber(), SetDeliveryType(), CurrentDeliveryType, and DisposeAsync() by delegating to extracted services.

#### Scenario: Interface methods delegate correctly
- **WHEN** StartAsync() is called
- **THEN** SHALL initialize WeighingStreamPipeline, subscribe to ILocalEventBus events, and start the async operation queue

#### Scenario: GetMostFrequentPlateNumber delegates
- **WHEN** GetMostFrequentPlateNumber() is called
- **THEN** SHALL return PlateNumberService.GetMostFrequentPlateNumber()

#### Scenario: GetCurrentStatus delegates
- **WHEN** GetCurrentStatus() is called
- **THEN** SHALL return WeighingStateManager.GetCurrentStatus()

### Requirement: Subscribe to ILocalEventBus external events on StartAsync
AttendedWeighingOrchestrator SHALL subscribe to:
- LicensePlateRecognizedEventData → delegate to PlateNumberService
- GhostGateSessionResetEventData → remove abandoned plate and publish updated plate
- SettingsSavedEventData → refresh runtime configuration (EnableLatestPlateNumber, EnablePlateRewrite)

#### Scenario: License plate event triggers plate cache update
- **WHEN** LicensePlateRecognizedEventData with plate "京A12345" is received
- **THEN** SHALL call PlateNumberService recognition method and publish PlateNumberChangedEventData

#### Scenario: Ghost gate session reset
- **WHEN** GhostGateSessionResetEventData with AbandonedPlateNumber="京A12345" is received
- **THEN** SHALL remove the plate from cache and publish PlateNumberChangedEventData with updated most frequent plate

#### Scenario: Settings saved refreshes runtime config
- **WHEN** SettingsSavedEventData is received
- **THEN** SHALL reload EnableLatestPlateNumber and EnablePlateRewrite from settings

### Requirement: Manage async operation queue
AttendedWeighingOrchestrator SHALL provide an async operation queue using Subject<Func<Task>> with Merge(maxConcurrent:5) for executing async side-effects (capture, record creation, cache reset) with retry(3) and error handling.

#### Scenario: Async operation enqueued
- **WHEN** EnqueueAsyncOperation(operation) is called
- **THEN** operation SHALL execute within the Merge(5) concurrency limit

#### Scenario: Fallback when stream not initialized
- **WHEN** EnqueueAsyncOperation is called but async stream is null
- **THEN** SHALL fall back to Task.Run with try/catch error logging

### Requirement: Handle status change side-effects
AttendedWeighingOrchestrator SHALL process status transition side-effects:
- OffScale → WaitingForStability: trigger Vzvision capture, log entry
- WaitingForStability → WeightStabilized: create weighing record with stable weight
- WaitingForStability → OffScale: capture all cameras, reset cycle
- WeightStabilized → OffScale: trigger capture, reset cycle
- WaitingForDeparture → OffScale: trigger capture, reset cycle, log completion

#### Scenario: Weight stabilized triggers record creation
- **WHEN** status transitions from WaitingForStability to WeightStabilized
- **THEN** SHALL enqueue WeighingRecordService.CreateWeighingRecordAsync with stable weight

#### Scenario: Normal departure resets cycle
- **WHEN** status transitions from WaitingForDeparture to OffScale
- **THEN** SHALL enqueue WeighingCaptureService.CaptureOnOffScale, then WeighingRecordService.RewriteAndResetCycle

### Requirement: Play audio announcements on status transitions
AttendedWeighingOrchestrator SHALL play audio announcements via ISoundDeviceService for specific transitions:
- OffScale → WaitingForStability: "车辆已上磅，正在称重"
- WaitingForDeparture → OffScale: "车辆已下磅，称重已完成"
- WaitingForStability → OffScale: "车辆已下磅"
- * → WeightStabilized: "称重已结束"

#### Scenario: Audio played on truck entry
- **WHEN** status transitions from OffScale to WaitingForStability
- **THEN** SHALL enqueue ISoundDeviceService.PlayTextV2Async("车辆已上磅，正在称重")

### Requirement: Graceful shutdown with pending operation completion
AttendedWeighingOrchestrator SHALL on StopAsync: dispose all Rx subscriptions, complete the async operation stream, and wait up to 5 minutes for pending operations to complete.

#### Scenario: Pending operations complete before shutdown
- **WHEN** StopAsync is called with 3 pending operations
- **THEN** SHALL wait for all to complete (up to 5 minutes timeout)

#### Scenario: Timeout on pending operations
- **WHEN** pending operations do not complete within 5 minutes
- **THEN** SHALL log warning and proceed with shutdown

### Requirement: Idempotent start
AttendedWeighingOrchestrator SHALL ignore duplicate StartAsync() calls if already started.

#### Scenario: Multiple start calls
- **WHEN** StartAsync() is called twice
- **THEN** SHALL only initialize streams and subscriptions once

### Requirement: Complete resource disposal
AttendedWeighingOrchestrator SHALL on DisposeAsync: call StopAsync, dispose all ILocalEventBus subscriptions, and dispose all internal BehaviorSubjects.

#### Scenario: Full disposal
- **WHEN** DisposeAsync is called
- **THEN** all subscriptions SHALL be disposed, all subjects SHALL be completed and disposed
