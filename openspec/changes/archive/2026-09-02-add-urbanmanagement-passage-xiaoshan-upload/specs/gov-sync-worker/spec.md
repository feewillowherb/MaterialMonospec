## ADDED Requirements

### Requirement: Independent passage pending queues

The Gov sync worker SHALL select pending checkpoint passage rows and pending finished-product passage rows in separate queries and process them with separate forward methods. Passage rows MUST NOT be loaded as `UrbanWeighingRecord`. A single `ProcessRecordAsync` MUST NOT branch on `PassageSource` to build three payloads.

#### Scenario: Checkpoint pending does not use weighing table

- **WHEN** a checkpoint passage is unsynced and eligible
- **THEN** the worker MUST enqueue it from the passage store filtered to checkpoint
- **AND** MUST NOT select it via `UrbanWeighingRecord` pending query

### Requirement: Weighing forward uses weighbridge channel

When forwarding `UrbanWeighingRecord`, the worker SHALL call the weighbridge save-record client, not the historical undifferentiated site `save` payload used as weighbridge.

#### Scenario: Weighing no longer posts mixed site save as weighbridge

- **WHEN** a pending weighing record is processed
- **THEN** the HTTP call MUST target `lantu/saveRecord`
- **AND** MUST NOT reuse checkpoint-only field sets as the weighbridge body
