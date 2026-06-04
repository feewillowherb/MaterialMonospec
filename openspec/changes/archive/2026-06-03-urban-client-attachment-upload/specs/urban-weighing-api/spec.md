## ADDED Requirements

### Requirement: Attachment upload endpoint for MaterialClient.Urban

UrbanManagement SHALL provide an application service endpoint (ABP conventional route) for MaterialClient.Urban to upload weighing-related images independently of `ReceiveAsync`, returning server-side `AttachmentFile` Guid values for use in `attachmentIds` on the receive payload.

#### Scenario: Conventional route for upload

- **WHEN** MaterialClient.Urban sends `POST` to the ABP-generated urban attachment upload route with valid JSON body
- **THEN** the system SHALL process images through `IFileService`
- **AND** SHALL return the list of created attachment Guids in the response body

### Requirement: End-to-end attachment association on receive

When MaterialClient.Urban calls receive with `attachmentIds` produced by the upload endpoint, the system SHALL create `UrbanWeighingRecordAttachment` join rows for a newly created weighing record.

#### Scenario: Receive with uploaded attachment Guids

- **WHEN** `ReceiveAsync` is called with a new `ClientRecordId` and `attachmentIds` containing Guids returned from the upload endpoint
- **THEN** the system SHALL insert the `UrbanWeighingRecord`
- **AND** SHALL create one `UrbanWeighingRecordAttachment` per Guid
- **AND** government sync worker SHALL later be able to read those files from `FilesPhysicalPath`-resolved storage
