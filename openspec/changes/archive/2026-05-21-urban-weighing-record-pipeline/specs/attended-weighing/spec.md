## MODIFIED Requirements

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
