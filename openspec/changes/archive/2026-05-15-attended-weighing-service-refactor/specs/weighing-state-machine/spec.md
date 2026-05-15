## ADDED Requirements

### Requirement: State transitions follow defined rules
WeighingStateManager SHALL manage an AttendedWeighingStatus state machine with exactly 4 states: OffScale, WaitingForStability, WeightStabilized, WaitingForDeparture. All transitions SHALL follow these rules:
- OffScale + weight > threshold → WaitingForStability
- WaitingForStability + weight < threshold → OffScale (abnormal departure)
- WaitingForStability + stability.IsStable + no existing record → WeightStabilized
- WeightStabilized + existing record → WaitingForDeparture
- WeightStabilized + weight < threshold → OffScale (abnormal)
- WaitingForDeparture + weight < threshold → OffScale (normal completion)

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

### Requirement: Force WaitingForDeparture when record exists and weight is above threshold
WeighingStateManager SHALL prevent regression from WaitingForDeparture to WeightStabilized or WaitingForStability when a weighing record already exists and weight remains above threshold.

#### Scenario: State forced to WaitingForDeparture
- **WHEN** a weighing record exists (recordId > 0), weight > MinWeightThreshold, and computed state is WeightStabilized or WaitingForStability
- **THEN** state SHALL be forced to WaitingForDeparture

### Requirement: Current status query
WeighingStateManager SHALL expose GetCurrentStatus() returning the current AttendedWeighingStatus value synchronously.

#### Scenario: Query current status
- **WHEN** GetCurrentStatus is called
- **THEN** SHALL return the most recent status value

### Requirement: Status change notification
WeighingStateManager SHALL accept status updates via UpdateStatus(AttendedWeighingStatus) and track previous status for transition detection.

#### Scenario: Status updated with previous tracking
- **WHEN** UpdateStatus(WaitingForStability) is called from OffScale
- **THEN** previous status SHALL be OffScale and current status SHALL be WaitingForStability

### Requirement: Delivery type management
WeighingStateManager SHALL manage a DeliveryType value (Receiving/Sending) with change notification via ILocalEventBus.

#### Scenario: Delivery type changed
- **WHEN** SetDeliveryType(Sending) is called and current type is Receiving
- **THEN** DeliveryTypeChangedEventData SHALL be published via ILocalEventBus

#### Scenario: Delivery type unchanged
- **WHEN** SetDeliveryType(Receiving) is called and current type is already Receiving
- **THEN** no event SHALL be published
