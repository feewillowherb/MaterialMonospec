## ADDED Requirements

### Requirement: Upload passage attachments before passage ingest

When MaterialClient.Urban submits a pending passage record, it SHALL upload associated local capture files via the existing UrbanManagement multipart attachment API and SHALL pass returned Guids on the checkpoint or finished-product ingest DTO. Missing files MUST be skipped with a warning without blocking remaining files.

#### Scenario: Passage with large photo uploads then ingest

- **WHEN** a pending checkpoint passage has a readable large capture file
- **THEN** the client SHALL multipart-upload that file
- **AND** SHALL include the returned Guid on checkpoint ingest
- **AND** SHALL NOT send Xiaoshan Base64 `snapImages` from the client
