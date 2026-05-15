## Why

AttendedWeighingService.cs (1539 lines) is a singleton service that directly handles Rx stream processing, state machine transitions, plate number caching with priority logic, camera capture orchestration, weighing record persistence, and event bus publishing — all in one class. This makes the service difficult to test (most unit tests are skipped due to timing sensitivity), risky to modify (any change can cascade across unrelated concerns), and hard to extend (new device types or flow variations require editing the same monolith).

## What Changes

- Split AttendedWeighingService into focused, independently testable services following SRP
- Extract state machine logic into a dedicated WeighingStateManager with explicit state transitions
- Extract plate number caching and selection logic (including priority/locked-at logic) into a dedicated service
- Extract Rx stream construction (weight, stability, status) into a dedicated stream pipeline builder
- Extract camera capture orchestration (Hikvision + Vzvision) into a dedicated service
- Extract weighing record persistence (create, rewrite plate, save photos) into a dedicated repository service
- Create a thin orchestrator that coordinates the above services via DI
- Maintain the existing IAttendedWeighingService interface contract so callers (ViewModel) require minimal changes
- Migrate existing tests to target individual services independently

## Capabilities

### New Capabilities

- `weighing-state-machine`: Encapsulates the OffScale → WaitingForStability → WeightStabilized → WaitingForDeparture → OffScale state transition logic with well-defined triggers and side-effects
- `plate-number-management`: Manages plate number recognition caching, priority/locked-at selection, color-based filtering, and recommendation integration
- `weighing-stream-pipeline`: Constructs and manages the reactive weight, stability, and status Rx streams with proper buffering, back-pressure, and error handling
- `weighing-device-capture`: Orchestrates camera capture (Hikvision JPEG batch + Vzvision LPR trigger) at various flow phases
- `weighing-record-persistence`: Handles WeighingRecord creation, plate number rewriting, delivery type updates, photo attachment saving, and TryMatch event publishing
- `weighing-orchestrator`: Thin coordinator that wires the above services together, manages lifecycle (start/stop/dispose), and subscribes to ILocalEventBus events

### Modified Capabilities

(none — no existing specs to modify)

## Impact

### Code Changes

| File Path | Change Type | Reason | Impact |
|-----------|-------------|--------|--------|
| `MaterialClient.Common/Services/AttendedWeighingService.cs` | **Remove** | Replaced by new modular services | All callers |
| `MaterialClient.Common/Services/AttendedWeighing/WeighingStateManager.cs` | New | State machine extraction | — |
| `MaterialClient.Common/Services/AttendedWeighing/PlateNumberService.cs` | New | Plate cache extraction | — |
| `MaterialClient.Common/Services/AttendedWeighing/WeighingStreamPipeline.cs` | New | Rx stream extraction | — |
| `MaterialClient.Common/Services/AttendedWeighing/WeighingCaptureService.cs` | New | Camera capture extraction | — |
| `MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs` | New | Persistence extraction | — |
| `MaterialClient.Common/Services/AttendedWeighing/AttendedWeighingOrchestrator.cs` | New | Main coordinator | — |
| `MaterialClient.Common/Services/IAttendedWeighingService.cs` | Modify | Keep interface, update implementation | ViewModel |
| `MaterialClient/ViewModels/AttendedWeighingViewModel.cs` | Minimal | Only if interface changes | UI layer |
| `MaterialClient.Common.Tests/Tests/AttendedWeighingServiceTests.cs` | Modify | Split into per-service test files | Tests |

### Dependencies
- No new external dependencies required
- Uses existing ABP ILocalEventBus, Reactive Extensions, DI system

### Systems
- Internal service only — no API or external system changes
