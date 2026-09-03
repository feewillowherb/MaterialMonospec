## MODIFIED Requirements

### Requirement: AttachmentFile entity for image storage

The system SHALL provide an `AttachmentFile` entity with fields: `Id` (Guid PK), `FileName` (string, max 200), `LocalPath` (string, max 1000), `AttachType` (`AttachType` enum, `short` underlying type, full definition aligned with `MaterialClient.Common.Entities.Enums.AttachType`: `UnmatchedEntryPhoto = 0`, `EntryPhoto = 1`, `ExitPhoto = 2`, `TicketPhoto = 3`, `Lrp = 5`, `UrbanPhoto = 6`), and `CreationTime` (DateTime, ABP audited; database column `CreationTime`). The entity SHALL map to the `AttachmentFile` database table. The entity MUST NOT expose `AddTime`.

#### Scenario: AttachmentFile entity creation

- **WHEN** an image is saved to disk during legacy or new client processing
- **THEN** the system SHALL create an `AttachmentFile` record with the file name, relative local path, appropriate `AttachType` enum value, and current timestamp in `CreationTime`
