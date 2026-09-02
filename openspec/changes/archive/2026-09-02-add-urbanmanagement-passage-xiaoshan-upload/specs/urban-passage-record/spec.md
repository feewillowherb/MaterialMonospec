## REMOVED Requirements

### Requirement: No upload in this change

**Reason:** Follow-up change `add-urbanmanagement-passage-xiaoshan-upload` adds client-to-UrbanManagement ingest. Direct Xiaoshan HTTP from the client remains forbidden.

**Migration:** Upload passage rows to UrbanManagement checkpoint and finished-product ingest APIs. Do not call Xiaoshan `inoutRecord/save` or `lantu/saveRecord` from MaterialClient.

## ADDED Requirements

### Requirement: Client uploads passage to UrbanManagement not Gov

MaterialClient.Urban SHALL upload pending checkpoint passage rows to the UrbanManagement checkpoint ingest API and pending finished-product rows to the finished-product ingest API. Weighing cloud upload MUST remain the existing weighing receive API. The client MUST NOT POST Xiaoshan Gov URLs for passage or weighing.

#### Scenario: Checkpoint cloud path

- **WHEN** a pending checkpoint `UrbanPassageRecord` is submitted to the server
- **THEN** the client MUST call the checkpoint ingest API
- **AND** MUST NOT call weighing `ReceiveAsync`
- **AND** MUST NOT call Xiaoshan `inoutRecord/save`

#### Scenario: Scale records unchanged

- **WHEN** a pending weighing record is submitted
- **THEN** the client MUST use the existing weighing receive path
