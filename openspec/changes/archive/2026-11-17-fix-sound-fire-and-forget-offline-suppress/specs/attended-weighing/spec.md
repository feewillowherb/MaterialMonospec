## MODIFIED Requirements

### Requirement: Play audio announcements on status transitions

AttendedWeighingOrchestrator SHALL play audio announcements via ISoundDeviceService for specific transitions:
- OffScale → WaitingForStability: "车辆已上磅，正在称重"
- WaitingForDeparture → OffScale: "车辆已下磅，称重已完成"
- WaitingForStability → OffScale: "车辆已下磅"
- * → WeightStabilized: "称重已结束"

Playback SHALL be fire-and-forget: the orchestrator MUST NOT enqueue announcement work on the weighing async operation queue (`EnqueueAsyncOperation` / `Merge(maxConcurrent: 5)`). The orchestrator MUST NOT await announcement completion on the status-transition path.

#### Scenario: Audio played on truck entry
- **WHEN** status transitions from OffScale to WaitingForStability
- **THEN** SHALL invoke ISoundDeviceService.PlayTextV2Async("车辆已上磅，正在称重") without enqueuing it on the weighing async operation queue
- **AND** MUST NOT await announcement completion before continuing other transition side-effects

#### Scenario: Announcement does not occupy weighing Merge slots
- **WHEN** a status transition triggers an audio announcement while five weighing async operations are already running
- **THEN** the announcement SHALL still be scheduled outside the weighing Merge queue
- **AND** weighing operations SHALL NOT wait for the announcement HTTP retries to finish
