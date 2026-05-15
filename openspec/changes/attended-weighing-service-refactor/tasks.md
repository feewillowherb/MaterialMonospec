## 1. Foundation — Record Types and Folder Structure

- [ ] 1.1 Create `Services/AttendedWeighing/` folder in MaterialClient.Common project
- [ ] 1.2 Extract `PlateNumberCacheRecord` from AttendedWeighingService.cs into its own file `Records/PlateNumberCacheRecord.cs` (keep in same namespace)
- [ ] 1.3 Extract `WeightStabilityInfo` from AttendedWeighingService.cs into its own file `Records/WeightStabilityInfo.cs` (keep in same namespace)
- [ ] 1.4 Verify project compiles after record type extraction (no namespace changes needed)

## 2. WeighingStateManager — State Machine Extraction

- [ ] 2.1 Create `Services/AttendedWeighing/WeighingStateManager.cs` with BehaviorSubject<AttendedWeighingStatus>, BehaviorSubject<DeliveryType>, and BehaviorSubject<long?> for recordId tracking
- [ ] 2.2 Implement `GetCurrentStatus()`, `UpdateStatus()`, `GetPreviousStatus()` methods
- [ ] 2.3 Implement `SetDeliveryType()` with ILocalEventBus notification
- [ ] 2.4 Implement `SetLastCreatedWeighingRecordId()` and `GetLastCreatedWeighingRecordId()` for record tracking
- [ ] 2.5 Implement `ResetCycle()` that resets recordId to null
- [ ] 2.6 Write unit tests for all state transitions (OffScale→WaitingForStability, WaitingForStability→OffScale, WaitingForStability→WeightStabilized, WeightStabilized→WaitingForDeparture, WaitingForDeparture→OffScale)
- [ ] 2.7 Write unit test for force-WaitingForDeparture when record exists

## 3. PlateNumberService — Plate Cache Extraction

- [ ] 3.1 Create `Services/AttendedWeighing/PlateNumberService.cs` with IPlateNumberService interface
- [ ] 3.2 Move ConcurrentDictionary<string, PlateNumberCacheRecord> and all cache management logic (AddOrUpdate, high/low priority, locked-at, 20-minute window)
- [ ] 3.3 Integrate RecommendPlateNumberService call in recognition method
- [ ] 3.4 Integrate PlateNumberValidator.FilterHangingCharacter in recognition method
- [ ] 3.5 Implement `GetMostFrequentPlateNumber()` with priority logic (locked → high-priority → low-priority)
- [ ] 3.6 Implement `ClearCache()` with PlateNumberChangedEventData(null) publish
- [ ] 3.7 Implement `RemovePlate(string)` for ghost gate session reset with case-insensitive matching
- [ ] 3.8 Implement `UpdateConfiguration(bool enableLatestPlateNumber, bool enablePlateRewrite)` for runtime config refresh
- [ ] 3.9 Write unit tests for: first recognition, count increment, locked-at selection, high/low priority, null color, concurrent access, cache clear, ghost removal

## 4. WeighingStreamPipeline — Rx Stream Extraction

- [ ] 4.1 Create `Services/AttendedWeighing/WeighingStreamPipeline.cs` with IWeighingStreamPipeline interface
- [ ] 4.2 Move `CreateWeightStream()` — Buffer(StabilityCheckIntervalMs), Select(last), StartWith(0m)
- [ ] 4.3 Move `CreateStabilityStream()` — Buffer(window, interval), valid-data filtering, minDataPoints calculation, range stability check, DistinctUntilChanged(IsStable), Replay(1).RefCount()
- [ ] 4.4 Move `CreateStatusStream()` — CombineLatest(weight, stability, recordId, status), state transition rules, DistinctUntilChanged
- [ ] 4.5 Implement `Build(IObservable<decimal> sharedSource, WeighingConfiguration config, WeighingStateManager stateManager)` that returns the combined stream
- [ ] 4.6 Write unit tests for weight stream buffering, stability detection with sufficient/insufficient data, status stream state transitions

## 5. WeighingCaptureService — Camera Capture Extraction

- [ ] 5.1 Create `Services/AttendedWeighing/WeighingCaptureService.cs` with IWeighingCaptureService interface
- [ ] 5.2 Move `CaptureAllCamerasAsync()` — camera config loading, BatchCaptureRequest construction, AttachmentPathUtils usage, batch execution, result filtering
- [ ] 5.3 Move `TriggerLprCaptureForAllAsync()` — EnableTriggerLprCapture check, LprDeviceType check, Vzvision device iteration, individual error handling
- [ ] 5.4 Add convenience methods: `CaptureOnWaitingForStability()`, `CaptureOnWeightStabilized()`, `CaptureOnOffScale()` that call TriggerLprCaptureForAllAsync with phase label
- [ ] 5.5 Write unit tests for: successful capture, partial failure, no cameras, Vzvision trigger enabled/disabled, non-Vzvision device type

## 6. WeighingRecordService — Persistence Extraction

- [ ] 6.1 Create `Services/AttendedWeighing/WeighingRecordService.cs` with IWeighingRecordService interface
- [ ] 6.2 Move `CreateWeighingRecordAsync()` — plate number retrieval, UoW scope, WeighingRecord construction with DeliveryType and WeighingMode, InsertAsync, event publish
- [ ] 6.3 Move `SaveCapturePhotosAsync()` — AttachmentFile creation with relative paths, WeighingRecordAttachment linking, UoW scope
- [ ] 6.4 Move `TryReWritePlateNumberAsync()` — EnablePlateRewrite check, plate update, DeliveryType update, UpdatePlateNumberEventData publish, TryMatchEvent publish
- [ ] 6.5 Implement `RewriteAndResetCycleAsync()` that calls TryReWritePlateNumberAsync then resets state manager cycle
- [ ] 6.6 Write unit tests for: record creation with/without plate, photo saving, plate rewrite enabled/disabled, DeliveryType update, TryMatch publish, duplicate prevention

## 7. AttendedWeighingOrchestrator — Coordinator Assembly

- [ ] 7.1 Create `Services/AttendedWeighing/AttendedWeighingOrchestrator.cs` implementing IAttendedWeighingService and ISingletonDependency
- [ ] 7.2 Inject all 5 extracted services via constructor (WeighingStateManager, PlateNumberService, WeighingStreamPipeline, WeighingCaptureService, WeighingRecordService) plus existing dependencies (ILogger, IConfiguration, ILocalEventBus, ISettingsService)
- [ ] 7.3 Implement `StartAsync()` — load configuration, initialize plate color filter, build stream pipeline, subscribe to status changes, subscribe to ILocalEventBus events (LicensePlateRecognized, GhostGateSessionReset, SettingsSaved), start async operation queue
- [ ] 7.4 Implement `OnWeightAndStatusChanged()` — delegate to state manager, check for record creation on stabilization, trigger capture at phase transitions
- [ ] 7.5 Implement `ProcessStatusTransition()` — audio announcements via ISoundDeviceService, phase-specific captures and resets
- [ ] 7.6 Implement async operation queue (Subject<Func<Task>>, Merge(5), Retry(3), fallback to Task.Run)
- [ ] 7.7 Implement `StopAsync()` — dispose subscriptions, complete async stream, wait for pending operations with 5-minute timeout
- [ ] 7.8 Implement `DisposeAsync()` — StopAsync + dispose event bus subscriptions + dispose BehaviorSubjects
- [ ] 7.9 Implement remaining IAttendedWeighingService members: GetCurrentStatus(), GetMostFrequentPlateNumber(), SetDeliveryType(), CurrentDeliveryType

## 8. Migration — Remove Old Service

- [ ] 8.1 Verify AttendedWeighingOrchestrator is registered via ABP ISingletonDependency auto-registration
- [ ] 8.2 Search codebase for all references to concrete AttendedWeighingService (not interface) and update to IAttendedWeighingService if needed
- [ ] 8.3 Delete `Services/AttendedWeighingService.cs` (the old monolithic file)
- [ ] 8.4 Update test file `AttendedWeighingServiceTests.cs` — split into per-service test files (WeighingStateManagerTests, PlateNumberServiceTests, WeighingStreamPipelineTests, WeighingCaptureServiceTests, WeighingRecordServiceTests, AttendedWeighingOrchestratorTests)
- [ ] 8.5 Migrate the TestLocalEventBus helper class to a shared test utility file
- [ ] 8.6 Run all tests and verify they pass (both new per-service tests and integration tests through Orchestrator)

## 9. Verification

- [ ] 9.1 Verify the application starts and the attended weighing page loads without errors
- [ ] 9.2 Verify full weighing cycle works: OffScale → WaitingForStability → WeightStabilized → WaitingForDeparture → OffScale
- [ ] 9.3 Verify plate recognition caching and selection works correctly
- [ ] 9.4 Verify camera capture triggers at correct phases
- [ ] 9.5 Verify weighing record creation and photo saving
- [ ] 9.6 Verify plate rewrite on departure works
- [ ] 9.7 Verify ghost gate session reset clears abandoned plate
- [ ] 9.8 Verify settings save refreshes runtime configuration
