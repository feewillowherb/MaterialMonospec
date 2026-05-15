## ADDED Requirements

### Requirement: Create weighing record on weight stabilization
WeighingRecordService SHALL create a WeighingRecord entity with the stabilized weight, current plate number from PlateNumberService, current DeliveryType, and WeighingMode from settings. The record SHALL be persisted via IRepository<WeighingRecord, long> within a UnitOfWork.

#### Scenario: Record created with all fields
- **WHEN** weight stabilizes at 1.5t, plate is "京A12345", DeliveryType is Receiving, WeighingMode is Standard
- **THEN** SHALL insert WeighingRecord with Weight=1.5t, PlateNumber="京A12345", DeliveryType=Receiving, WeighingMode=Standard

#### Scenario: Record created with no plate number
- **WHEN** weight stabilizes but no plate has been recognized (plate is null)
- **THEN** SHALL create record with PlateNumber=null

### Requirement: Publish WeighingRecordCreatedEventData after creation
WeighingRecordService SHALL publish WeighingRecordCreatedEventData(weighingRecordId) via ILocalEventBus after successful record creation and UoW completion.

#### Scenario: Event published after record creation
- **WHEN** a weighing record is created with ID 42
- **THEN** SHALL publish WeighingRecordCreatedEventData with WeighingRecordId=42

### Requirement: Save captured photos as attachments
WeighingRecordService SHALL save captured photo paths as AttachmentFile entities (AttachType.UnmatchedEntryPhoto) linked to the WeighingRecord via WeighingRecordAttachment, using relative paths for database portability.

#### Scenario: Photos saved as attachments
- **WHEN** 2 photo paths are provided for weighing record ID 42
- **THEN** SHALL create 2 AttachmentFile entries and 2 WeighingRecordAttachment link entries, converting to relative paths

#### Scenario: Photo file does not exist
- **WHEN** a photo path in the list does not exist on disk
- **THEN** SHALL skip that photo and log warning, continue with remaining photos

### Requirement: Rewrite plate number on departure
WeighingRecordService SHALL support rewriting the plate number and DeliveryType of the most recently created weighing record when the weighing cycle completes. If EnablePlateRewrite is true and the most frequent plate differs from the record's plate, update the record and publish UpdatePlateNumberEventData.

#### Scenario: Plate number rewritten
- **WHEN** EnablePlateRewrite=true, record has plate "京A00000", and most frequent plate is "京A12345"
- **THEN** SHALL update record plate to "京A12345" and publish UpdatePlateNumberEventData

#### Scenario: Plate rewrite disabled
- **WHEN** EnablePlateRewrite=false
- **THEN** SHALL skip plate number update and log debug

#### Scenario: Delivery type changed during weighing
- **WHEN** record has DeliveryType=Receiving but current DeliveryType is Sending
- **THEN** SHALL update record DeliveryType to Sending

### Requirement: Publish TryMatchEvent after rewrite cycle
WeighingRecordService SHALL publish TryMatchEvent(weighingRecordId) via ILocalEventBus after the rewrite cycle completes (whether or not changes were made), to trigger automatic matching.

#### Scenario: TryMatch published with no changes
- **WHEN** plate and delivery type are unchanged
- **THEN** SHALL still publish TryMatchEvent with the record ID

### Requirement: Prevent duplicate record creation
WeighingRecordService SHALL use a record ID tracker (BehaviorSubject<long?>) to ensure only one weighing record is created per weighing cycle. A null value means no record exists; a non-null value means a record was already created.

#### Scenario: Duplicate creation prevented
- **WHEN** CreateWeighingRecordAsync is called but recordId is already non-null
- **THEN** SHALL not create a second record

### Requirement: Reset record tracker for new cycle
WeighingRecordService SHALL provide ResetCycle() that clears the record ID tracker to null, enabling a new weighing cycle.

#### Scenario: Cycle reset
- **WHEN** ResetCycle() is called
- **THEN** record ID tracker SHALL be set to null
