## MODIFIED Requirements

### Requirement: Handle status change side-effects

AttendedWeighingOrchestrator SHALL process status transition side-effects:
- OffScale → WaitingForStability: log entry (MUST NOT trigger LPR active capture)
- WaitingForStability → WeightStabilized: create weighing record with stable weight, then LPR active capture when enabled
- WaitingForStability → OffScale: capture all cameras (gun cameras), reset cycle (MUST NOT trigger LPR active capture)
- WeightStabilized → OffScale: reset cycle (MUST NOT trigger LPR active capture)
- WaitingForDeparture → OffScale: reset cycle, log completion (MUST NOT trigger LPR active capture)

#### Scenario: Weight stabilized triggers record creation

- **WHEN** status transitions from WaitingForStability to WeightStabilized
- **THEN** SHALL enqueue weighing record creation with stable weight
- **AND** SHALL enqueue LPR active capture (`CaptureOnWeightStabilized`) when EnableTriggerLprCapture is true

#### Scenario: Normal departure resets cycle without LPR trigger

- **WHEN** status transitions from WaitingForDeparture to OffScale
- **THEN** SHALL enqueue WeighingRecordService.RewriteAndResetCycle
- **AND** MUST NOT enqueue LPR `CaptureOnOffScale`
