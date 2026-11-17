## ADDED Requirements

### Requirement: At most one stabilize-create enqueue per status callback

When `OnWeightAndStatusChanged` handles a weighing update, the orchestrator SHALL enqueue `OnWeightStabilizedAsync` (or equivalent create-on-stable work) at most once for that callback invocation. If the WaitingForStability → WeightStabilized status-transition path already enqueued create work, the same-callback backup path MUST NOT enqueue a second create.

#### Scenario: Status transition enqueue skips same-callback backup
- **WHEN** status transitions from WaitingForStability to WeightStabilized and recordId is null
- **AND** the orchestrator enqueues create-on-stable for that transition
- **THEN** the backup stabilize check in the same `OnWeightAndStatusChanged` invocation MUST NOT enqueue another create-on-stable

#### Scenario: Backup may still run on a later callback
- **WHEN** status is already WeightStabilized
- **AND** stability remains true
- **AND** recordId is still null
- **AND** this callback did not already enqueue create-on-stable
- **THEN** the orchestrator MAY enqueue a single create-on-stable as backup

## MODIFIED Requirements

### Requirement: Handle status change side-effects

AttendedWeighingOrchestrator SHALL process status transition side-effects:
- OffScale → WaitingForStability: log entry (MUST NOT trigger LPR active capture)
- WaitingForStability → WeightStabilized: create weighing record with stable weight, then LPR active capture when enabled
- WaitingForStability → OffScale: capture all cameras (gun cameras), reset cycle (MUST NOT trigger LPR active capture)
- WeightStabilized → OffScale: reset cycle (MUST NOT trigger LPR active capture)
- WaitingForDeparture → OffScale: reset cycle, log completion (MUST NOT trigger LPR active capture)

Create-on-stable scheduling for WaitingForStability → WeightStabilized MUST obey "At most one stabilize-create enqueue per status callback".

#### Scenario: Weight stabilized triggers record creation

- **WHEN** status transitions from WaitingForStability to WeightStabilized
- **THEN** SHALL enqueue weighing record creation with stable weight at most once for that callback
- **AND** SHALL enqueue LPR active capture (`CaptureOnWeightStabilized`) when EnableTriggerLprCapture is true
- **AND** MUST NOT also enqueue a second create via the same-callback backup check

#### Scenario: Normal departure resets cycle without LPR trigger

- **WHEN** status transitions from WaitingForDeparture to OffScale
- **THEN** SHALL enqueue WeighingRecordService.RewriteAndResetCycle
- **AND** MUST NOT enqueue LPR `CaptureOnOffScale`
